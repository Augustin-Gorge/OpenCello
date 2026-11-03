import Foundation

struct PitchSample {
    let time: TimeInterval
    let midi: Double
}

struct GlideInfo {
    let duration: TimeInterval
    let cents: Double
    let slope: Double

    var isGlide: Bool { duration >= 0.08 && abs(cents) >= 20 }
    var milliseconds: Double { duration * 1000 }
}

/// Détecte un portamento continu dans une série de hauteurs.
/// Un déplacement propre est une marche (saut) ; un glissé est une pente
/// continue de F0, de même signe, d'au moins ~50 cents/s.
enum GlideDetector {
    static func detect(
        samples: [PitchSample],
        minDuration: TimeInterval = 0.08,
        minSlope: Double = 50,
        minCents: Double = 20
    ) -> GlideInfo? {
        let ordered = samples
            .filter { $0.midi.isFinite }
            .sorted { $0.time < $1.time }
        guard ordered.count >= 4 else { return nil }

        let windowSize = 4
        var windows: [(start: Int, end: Int, slope: Double)] = []
        for start in 0...(ordered.count - windowSize) {
            let slice = Array(ordered[start..<(start + windowSize)])
            let dt = slice.last!.time - slice.first!.time
            guard dt >= 0.025 else { continue }
            let slope = linearSlope(
                x: slice.map(\.time),
                y: slice.map { $0.midi * 100 }
            )
            if abs(slope) >= minSlope {
                windows.append((start, start + windowSize - 1, slope))
            }
        }
        guard !windows.isEmpty else { return nil }

        var best: (start: Int, end: Int, slope: Double)?
        var current: (start: Int, end: Int, slope: Double)?

        for window in windows {
            guard let running = current else {
                current = window
                continue
            }
            let sameSign = (running.slope >= 0) == (window.slope >= 0)
            let contiguous = window.start <= running.end + 1
            if sameSign && contiguous {
                current = (running.start, max(running.end, window.end), (running.slope + window.slope) / 2)
            } else {
                if best == nil || span(current!) > span(best!) {
                    best = current
                }
                current = window
            }
        }
        if let current, best == nil || span(current) > span(best!) {
            best = current
        }

        guard let best else { return nil }
        let first = ordered[best.start]
        let last = ordered[best.end]
        let duration = last.time - first.time
        let cents = (last.midi - first.midi) * 100
        guard duration >= minDuration, abs(cents) >= minCents else { return nil }
        return GlideInfo(duration: duration, cents: cents, slope: cents / duration)
    }

    /// Analyse les extrémités d'une note : glissé d'attaque (début) et de
    /// relâchement (fin). Utilisé par `NoteSegmenter` pour enrichir `NoteEvent`.
    static func analyzeSegment(midis: [Double], times: [TimeInterval]) -> (attack: GlideInfo?, release: GlideInfo?) {
        guard midis.count == times.count, midis.count >= 6 else { return (nil, nil) }
        let samples = zip(times, midis).map { PitchSample(time: $0.0, midi: $0.1) }
        let split = max(3, samples.count * 3 / 5)
        let head = Array(samples.prefix(split))
        let tail = Array(samples.suffix(split))
        let attack = detect(samples: head)
        let release = detect(samples: tail)
        return (attack, release)
    }

    private static func span(_ item: (start: Int, end: Int, slope: Double)) -> Int {
        item.end - item.start
    }

    private static func linearSlope(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        var numerator = 0.0
        var denominator = 0.0
        for index in 0..<x.count {
            let dx = x[index] - meanX
            numerator += dx * (y[index] - meanY)
            denominator += dx * dx
        }
        guard denominator > 0.0000001 else { return 0 }
        return numerator / denominator
    }
}

/// Suit les techniques particulières au fil de la séance :
/// - piqué : séries de notes courtes, égalité des durées et des énergies (B17) ;
/// - glissé : transitions glissées volontaires (glissando écrit) vs parasites (B14).
final class TechniqueTracker {
    private var piqueRun: [(duration: Double, rms: Double)] = []
    private var lastPiqueEnd: TimeInterval?

    private(set) var piqueNotes = 0
    private(set) var piqueUnevenRuns = 0
    private var durationCVs: [Double] = []
    private var energyCVs: [Double] = []
    private(set) var worstPiqueIndex: Int?
    private(set) var worstPiqueDeviation: Double?

    private(set) var glideShifts = 0
    private(set) var parasiteGlides = 0
    private(set) var voluntaryGlides = 0
    private var glideDurations: [Double] = []
    private var glideSlopes: [Double] = []

    func reset() {
        piqueRun = []
        lastPiqueEnd = nil
        piqueNotes = 0
        piqueUnevenRuns = 0
        durationCVs = []
        energyCVs = []
        worstPiqueIndex = nil
        worstPiqueDeviation = nil
        glideShifts = 0
        parasiteGlides = 0
        voluntaryGlides = 0
        glideDurations = []
        glideSlopes = []
    }

    func addNote(_ event: NoteEvent, articulation: Articulation, gapBefore: Double) {
        let isPique = event.duration < 0.25 && gapBefore > 0.03
        let classified = articulation == .staccato || articulation == .martele
        guard isPique || classified else {
            flushPiqueRun()
            return
        }

        if let lastPiqueEnd, event.startTime - lastPiqueEnd > 1.2 {
            flushPiqueRun()
        }
        piqueRun.append((event.duration, event.meanRMS))
        lastPiqueEnd = event.endTime
        piqueNotes += 1
    }

    func addShift(glide: GlideInfo?, voluntary: Bool) {
        guard let glide, glide.duration >= 0.08 else { return }
        glideShifts += 1
        glideDurations.append(glide.milliseconds)
        glideSlopes.append(glide.slope)
        if voluntary {
            voluntaryGlides += 1
        } else if glide.duration >= 0.15 {
            parasiteGlides += 1
        }
    }

    func record() -> TechniqueRecord? {
        flushPiqueRun()
        guard piqueNotes > 0 || glideShifts > 0 else { return nil }
        return TechniqueRecord(
            piqueNotes: piqueNotes,
            piqueUnevenRuns: piqueUnevenRuns,
            piqueMeanDurationCV: mean(durationCVs),
            piqueMeanEnergyCV: mean(energyCVs),
            piqueWorstIndex: worstPiqueIndex,
            piqueWorstDeviation: worstPiqueDeviation,
            glideShifts: glideShifts,
            parasiteGlides: parasiteGlides,
            voluntaryGlides: voluntaryGlides,
            meanGlideMs: mean(glideDurations),
            meanGlideSlope: mean(glideSlopes)
        )
    }

    private func flushPiqueRun() {
        guard piqueRun.count >= 4 else {
            piqueRun = []
            return
        }
        let durations = piqueRun.map(\.duration)
        let energies = piqueRun.map(\.rms)
        let durationMean = durations.reduce(0, +) / Double(durations.count)
        let energyMean = energies.reduce(0, +) / Double(energies.count)
        let durationCV = coefficientOfVariation(durations, mean: durationMean)
        let energyCV = coefficientOfVariation(energies, mean: energyMean)
        durationCVs.append(durationCV)
        energyCVs.append(energyCV)

        if durationCV > 0.12 {
            piqueUnevenRuns += 1
            if let index = durations.enumerated().min(by: { abs($0.element - durationMean) > abs($1.element - durationMean) })?.offset {
                worstPiqueIndex = index + 1
                worstPiqueDeviation = (durations[index] - durationMean) / max(0.001, durationMean)
            }
        }
        piqueRun = []
    }

    private func coefficientOfVariation(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1, mean > 0 else { return 0 }
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot() / mean
    }

    private func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
