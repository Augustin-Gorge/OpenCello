import Foundation
import AVFoundation

/// Construit des « moments » de replay à partir des statistiques stockées.
/// Aucun audio brut n'est conservé : le rejeu est toujours re-synthétisé.
enum ReplayBuilder {
    static func moments(
        from notes: [NotePositionRecord],
        technique: TechniqueRecord?,
        maxCount: Int = 6
    ) -> [ReplayMoment] {
        guard !notes.isEmpty else { return [] }
        let scored = notes.filter { $0.scoreIndex != nil }
        guard !scored.isEmpty else { return [] }

        var moments: [ReplayMoment] = []

        if let worst = scored.max(by: { abs($0.cents) < abs($1.cents) }), abs(worst.cents) >= 30 {
            moments.append(moment(
                kind: "Justesse",
                target: worst,
                notes: notes,
                title: "Justesse — mesure \(worst.measure ?? 0)",
                detail: String(format: "%+.0f cents sur la note attendue", worst.cents),
                advice: "Isole cette note, vérifie le doigt et la corde, puis rejoue la phrase lentement avec un bourdon."
            ))
        }

        if let worst = scored.compactMap({ note -> (NotePositionRecord, Double)? in
            guard let rhythm = note.rhythmMs else { return nil }
            return (note, rhythm)
        }).max(by: { abs($0.1) < abs($1.1) }), abs(worst.1) >= 180 {
            moments.append(moment(
                kind: "Rythme",
                target: worst.0,
                notes: notes,
                title: "Rythme — mesure \(worst.0.measure ?? 0)",
                detail: String(format: "%+.0f ms par rapport à la grille", worst.1),
                advice: "Compte la pulsation à voix haute et laisse la note suivante partir au bon moment."
            ))
        }

        if let glide = scored
            .filter({ $0.isShift && !$0.isVoluntaryGlide && ($0.glideMs ?? 0) >= 150 })
            .max(by: { ($0.glideMs ?? 0) < ($1.glideMs ?? 0) }) {
            moments.append(moment(
                kind: "Glissé",
                target: glide,
                notes: notes,
                title: "Glissé — mesure \(glide.measure ?? 0)",
                detail: String(format: "portamento de %.0f ms vers la %@", glide.glideMs ?? 0, glide.positionText),
                advice: "Pose le doigt d'un coup sec : c'est le coude qui accompagne la main, pas le doigt qui traîne sur la corde."
            ))
        }

        if let shift = scored
            .filter({ $0.isShift && abs($0.cents) >= 25 })
            .max(by: { abs($0.cents) < abs($1.cents) }) {
            moments.append(moment(
                kind: "Déplacement",
                target: shift,
                notes: notes,
                title: "Arrivée de déplacement — mesure \(shift.measure ?? 0)",
                detail: String(format: "%@, %@ : %+.0f cents", shift.positionText, shift.fingerText, shift.cents),
                advice: "Travaille la descente seule, lentement, en vérifiant la note d'arrivée avant de réintégrer la phrase."
            ))
        }

        if let worstGroup = worstPositionGroup(scored) {
            moments.append(moment(
                kind: "Doigt",
                target: worstGroup.note,
                notes: notes,
                title: "Doigté — mesure \(worstGroup.note.measure ?? 0)",
                detail: String(
                    format: "%@ en %@ : %.0f cents d'écart moyen sur %d notes",
                    worstGroup.note.fingerText,
                    worstGroup.note.positionText,
                    worstGroup.meanAbsCents,
                    worstGroup.count
                ),
                advice: "Isole ce doigté et répète le passage sans vibrato pour entendre la justesse."
            ))
        }

        if let technique, technique.piqueUnevenRuns > 0,
           let target = scored.filter({
               let kind = $0.articulation ?? ""
               return kind == Articulation.staccato.rawValue || kind == Articulation.martele.rawValue
           }).min(by: { $0.duration < $1.duration }) {
            let deviation = technique.piqueWorstDeviation.map { String(format: "%.0f %%", abs($0) * 100) } ?? "—"
            moments.append(moment(
                kind: "Piqué",
                target: target,
                notes: notes,
                title: "Piqué inégal — mesure \(target.measure ?? 0)",
                detail: "série inégale : écart de durée \(deviation), \(technique.piqueUnevenRuns) série(s) concernée(s)",
                advice: "Vise des notes égales : arrête l'archet à la même vitesse et repars exactement pareil à chaque note."
            ))
        }

        var seen = Set<String>()
        return moments
            .filter { seen.insert($0.kind).inserted }
            .prefix(maxCount)
            .map { $0 }
    }

    static func liveMoment(
        feedback: FollowFeedback,
        event: NoteEvent?,
        assignment: PositionAssignment?,
        indexedNotes: [(index: Int, note: ScoreNote)],
        currentIndex: Int,
        bpm: Double
    ) -> ReplayMoment? {
        guard let current = indexedNotes.first(where: { $0.index == currentIndex })?.note else { return nil }
        let secondsPerBeat = 60 / max(30, bpm)
        let replayNotes: [ReplayNote] = indexedNotes.map { item in
            let note = item.note
            let isCurrent = item.index == currentIndex
            return ReplayNote(
                scoreIndex: item.index,
                measure: note.measureIndex,
                beat: max(1, note.onsetBeats - note.measureStartBeats + 1),
                midi: note.midi,
                onset: (note.onsetBeats - current.onsetBeats) * secondsPerBeat,
                duration: max(0.08, note.durationBeats * secondsPerBeat),
                cents: isCurrent ? (feedback.cents ?? 0) : 0,
                contour: isCurrent ? (event?.centsContour ?? []) : [],
                rhythmMs: isCurrent ? (feedback.rhythmMs ?? 0) : 0
            )
        }

        let position = assignment?.position
        let finger = assignment?.finger
        let positionText = position.map { "\($0)e position" } ?? "position non mesurée"
        let fingerText = finger.map { $0 == 0 ? "corde à vide" : "\($0)e doigt" } ?? "doigté non mesuré"
        let glide = event?.glideDuration.map { $0 * 1000 }
        return ReplayMoment(
            kind: "Marqué",
            title: "Moment marqué — mesure \(feedback.measure ?? 0)",
            detail: "\(positionText), \(fingerText) · \(String(format: "%+.0f cents", feedback.cents ?? 0))",
            advice: "Rejoue ce passage isolé, puis réintègre-le dans la phrase.",
            measure: feedback.measure,
            beat: feedback.beat,
            scoreIndex: currentIndex,
            expectedMidi: feedback.expectedMidi,
            cents: feedback.cents,
            rhythmMs: feedback.rhythmMs,
            glideMs: glide,
            position: position,
            finger: finger,
            notes: replayNotes
        )
    }

    private static func moment(
        kind: String,
        target: NotePositionRecord,
        notes: [NotePositionRecord],
        title: String,
        detail: String,
        advice: String
    ) -> ReplayMoment {
        let window = windowNotes(around: target, all: notes)
        return ReplayMoment(
            kind: kind,
            title: title,
            detail: detail,
            advice: advice,
            measure: target.measure,
            beat: target.beat,
            scoreIndex: target.scoreIndex,
            expectedMidi: target.expectedMidi,
            cents: target.cents,
            rhythmMs: target.rhythmMs,
            glideMs: target.glideMs,
            position: target.position,
            finger: target.finger,
            notes: window
        )
    }

    private static func windowNotes(around target: NotePositionRecord, all notes: [NotePositionRecord]) -> [ReplayNote] {
        let scored = notes.filter { $0.scoreIndex != nil }
        let window: [NotePositionRecord]
        if let index = target.scoreIndex {
            window = scored.filter { note in
                guard let noteIndex = note.scoreIndex else { return false }
                return abs(noteIndex - index) <= 2
            }
        } else {
            window = scored
        }
        let base = window.map(\.onset).min() ?? 0
        return window.map { note in
            ReplayNote(
                scoreIndex: note.scoreIndex ?? 0,
                measure: note.measure ?? 0,
                beat: note.beat ?? 1,
                midi: note.expectedMidi ?? note.playedMidi,
                onset: note.onset - base,
                duration: max(0.08, note.duration),
                cents: note.cents,
                contour: note.contour,
                rhythmMs: note.rhythmMs ?? 0
            )
        }
    }

    private static func worstPositionGroup(_ notes: [NotePositionRecord]) -> (note: NotePositionRecord, meanAbsCents: Double, count: Int)? {
        var groups: [String: [NotePositionRecord]] = [:]
        for note in notes {
            guard let position = note.position, let finger = note.finger else { continue }
            groups["\(position)-\(finger)", default: []].append(note)
        }
        let candidates = groups.values.compactMap { samples -> (NotePositionRecord, Double, Int)? in
            guard let first = samples.first, samples.count >= 2 else { return nil }
            let mean = samples.map { abs($0.cents) }.reduce(0, +) / Double(samples.count)
            guard mean >= 25 else { return nil }
            return (first, mean, samples.count)
        }
        return candidates.max { $0.1 < $1.1 }.map { (note: $0.0, meanAbsCents: $0.1, count: $0.2) }
    }
}

/// Synthèse locale « ce que tu as fait » / « ce que ça devrait être ».
/// Sinusoïde + harmoniques + ADSR : aucun SoundFont, aucune dépendance.
enum ReplaySynth {
    static let defaultSampleRate: Double = 44_100

    static func render(
        moment: ReplayMoment,
        corrected: Bool,
        sampleRate: Double = defaultSampleRate
    ) -> [Float] {
        let notes = moment.notes.sorted { $0.onset < $1.onset }
        guard !notes.isEmpty else { return [] }

        let base = notes.map(\.onset).min() ?? 0
        let end = notes.map { $0.onset + $0.duration }.max() ?? 1
        let total = max(0.25, end - base + 0.35)
        var samples = [Float](repeating: 0, count: Int(total * sampleRate))

        for note in notes {
            let rhythmOffset = corrected ? 0 : note.rhythmMs / 1000
            let start = max(0, note.onset - base + rhythmOffset)
            let duration = max(0.06, note.duration)
            let fallbackCents = corrected ? 0 : note.cents
            let contour = corrected ? [] : note.contour
            addTone(
                into: &samples,
                start: start,
                duration: duration,
                midi: Double(note.midi),
                contour: contour.isEmpty ? [fallbackCents] : contour,
                sampleRate: sampleRate,
                amplitude: 0.55
            )
        }

        if !corrected, let glideMs = moment.glideMs, glideMs >= 80,
           let target = notes.first(where: { $0.scoreIndex == moment.scoreIndex }) {
            let targetStart = target.onset - base + target.rhythmMs / 1000
            let glideDuration = glideMs / 1000
            let previous = notes.filter { $0.scoreIndex < target.scoreIndex }.max(by: { $0.scoreIndex < $1.scoreIndex })
            let fromMidi = Double(previous?.midi ?? (target.midi - 2))
            let start = max(0, targetStart - glideDuration)
            addGlide(
                into: &samples,
                start: start,
                duration: min(glideDuration, max(0.05, targetStart - start)),
                fromMidi: fromMidi,
                toMidi: Double(target.midi),
                sampleRate: sampleRate,
                amplitude: 0.35
            )
        }

        let peak = samples.map { abs($0) }.max() ?? 0
        if peak > 0 {
            let gain = 0.78 / peak
            for index in samples.indices { samples[index] *= gain }
        }
        applyFade(&samples, sampleRate: sampleRate)
        return samples
    }

    private static func addTone(
        into samples: inout [Float],
        start: Double,
        duration: Double,
        midi: Double,
        contour: [Double],
        sampleRate: Double,
        amplitude: Double
    ) {
        guard !samples.isEmpty, duration > 0 else { return }
        let startIndex = max(0, Int(start * sampleRate))
        let count = min(samples.count - startIndex, Int(duration * sampleRate))
        guard count > 0 else { return }
        var phase = 0.0
        let attack = max(1, Int(0.012 * sampleRate))
        let release = max(1, Int(0.07 * sampleRate))
        for offset in 0..<count {
            let progress = Double(offset) / Double(max(1, count - 1))
            let cents = interpolate(contour, progress)
            let frequency = 440 * pow(2, (midi + cents / 100 - 69) / 12)
            phase += 2 * Double.pi * frequency / sampleRate
            let envelope = adsr(
                index: offset,
                count: count,
                attack: attack,
                release: release
            )
            let value = sin(phase)
                + 0.45 * sin(2 * phase)
                + 0.20 * sin(3 * phase)
                + 0.10 * sin(4 * phase)
            samples[startIndex + offset] += Float(value * envelope * amplitude / 1.75)
        }
    }

    private static func addGlide(
        into samples: inout [Float],
        start: Double,
        duration: Double,
        fromMidi: Double,
        toMidi: Double,
        sampleRate: Double,
        amplitude: Double
    ) {
        guard !samples.isEmpty, duration > 0 else { return }
        let startIndex = max(0, Int(start * sampleRate))
        let count = min(samples.count - startIndex, Int(duration * sampleRate))
        guard count > 0 else { return }
        var phase = 0.0
        for offset in 0..<count {
            let progress = Double(offset) / Double(max(1, count - 1))
            let midi = fromMidi + (toMidi - fromMidi) * progress
            let frequency = 440 * pow(2, (midi - 69) / 12)
            phase += 2 * Double.pi * frequency / sampleRate
            let envelope = sin(Double.pi * progress)
            samples[startIndex + offset] += Float(sin(phase) * envelope * amplitude)
        }
    }

    private static func interpolate(_ values: [Double], _ progress: Double) -> Double {
        guard let first = values.first else { return 0 }
        guard values.count > 1 else { return first }
        let position = max(0, min(1, progress)) * Double(values.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(values.count - 1, lower + 1)
        let fraction = position - Double(lower)
        return values[lower] * (1 - fraction) + values[upper] * fraction
    }

    private static func adsr(index: Int, count: Int, attack: Int, release: Int) -> Double {
        if index < attack {
            return Double(index) / Double(attack)
        }
        if index > count - release {
            return max(0, Double(count - index) / Double(release))
        }
        return 0.82
    }

    private static func applyFade(_ samples: inout [Float], sampleRate: Double) {
        let fade = min(samples.count / 4, Int(0.01 * sampleRate))
        guard fade > 0 else { return }
        for index in 0..<fade {
            let gain = Float(index) / Float(fade)
            samples[index] *= gain
            samples[samples.count - 1 - index] *= gain
        }
    }
}

@MainActor
final class ReplayAudioEngine: ObservableObject {
    @Published var isPlaying = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = ReplaySynth.defaultSampleRate
    private var configured = false

    func play(moment: ReplayMoment, corrected: Bool) {
        stop()
        let samples = ReplaySynth.render(moment: moment, corrected: corrected, sampleRate: sampleRate)
        guard !samples.isEmpty, let buffer = makeBuffer(samples) else { return }
        configureIfNeeded()
        do {
            try engine.start()
        } catch {
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        player.play()
        isPlaying = true
    }

    func stop() {
        player.stop()
        isPlaying = false
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        configured = true
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for index in samples.indices {
            channel[index] = samples[index]
        }
        return buffer
    }
}
