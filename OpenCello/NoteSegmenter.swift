import Foundation

struct NoteEvent {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let midi: Double
    let frequency: Double
    let centsToNearest: Double
    let stabilityCents: Double
    let meanRMS: Double
    let rmsVariation: Double
    let attackTime: Double
    let tailRatio: Double
    let centroid: Double
    let flatness: Double
    let highBandRatio: Double
    let hnr: Double
    let confidence: Double
    let vibratoRate: Double?
    let vibratoExtent: Double?

    // Phase 7 : glissé/portamento et contour de cents (replay pédagogique).
    var attackGlideCents: Double? = nil
    var releaseGlideCents: Double? = nil
    var glideDuration: Double? = nil
    var glideSlope: Double? = nil
    var centsContour: [Double] = []

    var duration: TimeInterval { max(0, endTime - startTime) }
}

enum SegmenterOutput {
    case started(midi: Double, time: TimeInterval)
    case finished(NoteEvent)
}

/// Segmente le flux de hauteur en notes et agrège les métriques par note.
/// Émet `.started` dès qu'une note commence (pour le suivi de partition)
/// et `.finished` à la frontière suivante (métriques complètes).
final class NoteSegmenter {
    private struct Segment {
        var startTime: TimeInterval
        var lastTime: TimeInterval
        var midis: [Double]
        var frequencies: [Double]
        var times: [TimeInterval]
        var rms: [Double]
        var centroids: [Double]
        var flatness: [Double]
        var highBand: [Double]
        var hnr: [Double]
        var confidences: [Double]
        var lastMidi: Double
    }

    private var current: Segment?
    private let minDuration: TimeInterval = 0.12
    private let minSamples = 4
    private let silenceRMS: Double = 0.012

    func add(_ frame: PitchFrame, spectral: SpectralFrame?) -> [SegmenterOutput] {
        var outputs: [SegmenterOutput] = []

        guard let frequency = frame.frequency, frequency > 0, frame.rms >= silenceRMS else {
            if let segment = current, frame.timestamp - segment.lastTime > 0.08 {
                if let event = finish(segment) {
                    outputs.append(.finished(event))
                }
                current = nil
            }
            return outputs
        }

        let midi = 69 + 12 * log2(frequency / 440)

        if var segment = current {
            if abs(midi - segment.lastMidi) > 1.0, frame.timestamp - segment.startTime >= 0.10 {
                if let event = finish(segment) {
                    outputs.append(.finished(event))
                }
                current = makeSegment(frame: frame, midi: midi, spectral: spectral)
                outputs.append(.started(midi: midi, time: frame.timestamp))
            } else {
                append(frame: frame, midi: midi, spectral: spectral, to: &segment)
                current = segment
            }
        } else {
            current = makeSegment(frame: frame, midi: midi, spectral: spectral)
            outputs.append(.started(midi: midi, time: frame.timestamp))
        }

        return outputs
    }

    func flush() -> NoteEvent? {
        guard let segment = current else { return nil }
        current = nil
        return finish(segment)
    }

    func reset() {
        current = nil
    }

    private func makeSegment(frame: PitchFrame, midi: Double, spectral: SpectralFrame?) -> Segment {
        Segment(
            startTime: frame.timestamp,
            lastTime: frame.timestamp,
            midis: [midi],
            frequencies: [frame.frequency ?? 0],
            times: [frame.timestamp],
            rms: [frame.rms],
            centroids: spectral.map { [$0.centroid] } ?? [],
            flatness: spectral.map { [$0.flatness] } ?? [],
            highBand: spectral.map { [$0.highBandRatio] } ?? [],
            hnr: spectral.map { [$0.hnr] } ?? [],
            confidences: [frame.confidence],
            lastMidi: midi
        )
    }

    private func append(frame: PitchFrame, midi: Double, spectral: SpectralFrame?, to segment: inout Segment) {
        segment.lastTime = frame.timestamp
        segment.lastMidi = midi
        segment.midis.append(midi)
        segment.frequencies.append(frame.frequency ?? segment.frequencies.last ?? 0)
        segment.times.append(frame.timestamp)
        segment.rms.append(frame.rms)
        segment.confidences.append(frame.confidence)
        if let spectral {
            segment.centroids.append(spectral.centroid)
            segment.flatness.append(spectral.flatness)
            segment.highBand.append(spectral.highBandRatio)
            segment.hnr.append(spectral.hnr)
        }
    }

    private func finish(_ segment: Segment) -> NoteEvent? {
        let duration = segment.lastTime - segment.startTime
        guard duration >= minDuration,
              segment.midis.count >= minSamples,
              !segment.frequencies.isEmpty else { return nil }

        let sortedFrequencies = segment.frequencies.sorted()
        let medianFrequency = sortedFrequencies[sortedFrequencies.count / 2]
        let sortedMidis = segment.midis.sorted()
        let medianMidi = sortedMidis[sortedMidis.count / 2]

        let cents = segment.midis.map { ($0 - medianMidi) * 100 }
        let meanCents = cents.reduce(0, +) / Double(max(1, cents.count))
        let variance = cents.map { ($0 - meanCents) * ($0 - meanCents) }.reduce(0, +) / Double(max(1, cents.count))
        let stability = variance.squareRoot()

        let meanRMS = mean(segment.rms)
        let rmsVariation: Double
        if meanRMS > 0, segment.rms.count > 1 {
            let rmsVariance = segment.rms.map { ($0 - meanRMS) * ($0 - meanRMS) }.reduce(0, +) / Double(segment.rms.count)
            rmsVariation = rmsVariance.squareRoot() / meanRMS
        } else {
            rmsVariation = 0
        }

        let peakRMS = segment.rms.max() ?? 0
        var attackTime = duration
        if peakRMS > 0, let index = segment.rms.firstIndex(where: { $0 >= peakRMS * 0.9 }) {
            attackTime = max(0, segment.times[index] - segment.startTime)
        }

        let tailCount = max(1, segment.rms.count / 5)
        let tailMean = mean(Array(segment.rms.suffix(tailCount)))
        let tailRatio = peakRMS > 0 ? tailMean / peakRMS : 0

        let vibrato = VibratoAnalyzer.estimate(
            midis: segment.midis,
            timestamps: segment.times
        )

        let glide = GlideDetector.analyzeSegment(midis: segment.midis, times: segment.times)
        let glideDuration = max(glide.attack?.duration ?? 0, glide.release?.duration ?? 0)
        let glideSlope = (glide.attack?.duration ?? 0) >= (glide.release?.duration ?? 0)
            ? glide.attack?.slope
            : glide.release?.slope

        var event = NoteEvent(
            startTime: segment.startTime,
            endTime: segment.lastTime,
            midi: medianMidi,
            frequency: medianFrequency,
            centsToNearest: (medianMidi - medianMidi.rounded()) * 100,
            stabilityCents: stability,
            meanRMS: meanRMS,
            rmsVariation: rmsVariation,
            attackTime: attackTime,
            tailRatio: tailRatio,
            centroid: mean(segment.centroids),
            flatness: mean(segment.flatness),
            highBandRatio: mean(segment.highBand),
            hnr: mean(segment.hnr),
            confidence: mean(segment.confidences),
            vibratoRate: vibrato?.rate,
            vibratoExtent: vibrato?.extent
        )
        event.attackGlideCents = glide.attack?.cents
        event.releaseGlideCents = glide.release?.cents
        event.glideDuration = glideDuration > 0 ? glideDuration : nil
        event.glideSlope = glideDuration > 0 ? glideSlope : nil
        event.centsContour = Self.contour(segment.midis, reference: medianMidi)
        return event
    }

    /// Réduit le contour de hauteur à 8 points (cents relatifs à la note
    /// médiane) pour un replay léger, sans stocker l'audio.
    private static func contour(_ midis: [Double], reference: Double) -> [Double] {
        guard !midis.isEmpty else { return [] }
        let maxPoints = 8
        guard midis.count > maxPoints else {
            return midis.map { ($0 - reference) * 100 }
        }
        return (0..<maxPoints).map { index in
            let position = Double(index) * Double(midis.count - 1) / Double(maxPoints - 1)
            let lower = Int(position.rounded(.down))
            let upper = min(midis.count - 1, lower + 1)
            let fraction = position - Double(lower)
            let value = midis[lower] * (1 - fraction) + midis[upper] * fraction
            return (value - reference) * 100
        }
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
