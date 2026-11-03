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
                rhythmMs: isCurrent ? (feedback.rhythmMs ?? 0) : 0,
                expectedDuration: max(0.08, note.durationBeats * secondsPerBeat),
                velocity: note.velocity,
                scoreArticulation: note.scoreArticulation
            )
        }

        let position = assignment?.position
        let finger = assignment?.finger
        let isThumb = finger == 5
        let positionText = position.map {
            isThumb ? "position du pouce \($0)e" : "\($0)e position"
        } ?? "position non mesurée"
        let fingerText = finger.map { $0 == 0 ? "corde à vide" : ($0 == 5 ? "pouce" : "\($0)e doigt") } ?? "doigté non mesuré"
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
                rhythmMs: note.rhythmMs ?? 0,
                expectedDuration: note.expectedDuration,
                velocity: note.velocity,
                scoreArticulation: note.scoreArticulation
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
        let end = notes.map { note in
            note.onset + max(note.duration, corrected ? (note.expectedDuration ?? note.duration) : 0)
        }.max() ?? 1
        let total = max(0.25, end - base + 0.35)
        var samples = [Float](repeating: 0, count: Int(total * sampleRate))

        for note in notes {
            let rhythmOffset = corrected ? 0 : note.rhythmMs / 1000
            let start = max(0, note.onset - base + rhythmOffset)
            var duration = max(0.06, corrected ? (note.expectedDuration ?? note.duration) : note.duration)
            if corrected {
                duration *= articulationFactor(note.scoreArticulation)
            }
            let fallbackCents = corrected ? 0 : note.cents
            let contour = corrected ? [] : note.contour
            let velocity = Double(note.velocity ?? 90) / 127
            let amplitude = 0.35 + 0.45 * velocity
            addTone(
                into: &samples,
                start: start,
                duration: duration,
                midi: Double(note.midi),
                contour: contour.isEmpty ? [fallbackCents] : contour,
                sampleRate: sampleRate,
                amplitude: amplitude
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

    static func articulationFactor(_ articulation: String?) -> Double {
        switch articulation?.lowercased() {
        case "staccato", "spiccato": return 0.55
        case "marcato": return 0.45
        case "tenuto": return 1.05
        default: return 1.0
        }
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
            // Vibrato progressif (≈5,2 Hz, ±6 cents) : la corde frottée
            // n'est jamais parfaitement droite.
            let vibratoDepth = 6.0 * min(1, max(0, (progress - 0.18) / 0.35))
            let vibrato = sin(2 * Double.pi * 5.2 * Double(offset) / sampleRate) * vibratoDepth
            let frequency = 440 * pow(2, (midi + (cents + vibrato) / 100 - 69) / 12)
            phase += 2 * Double.pi * frequency / sampleRate
            let envelope = adsr(
                index: offset,
                count: count,
                attack: attack,
                release: release
            )
            var value = 0.0
            for harmonic in 1...8 {
                let harmonicFrequency = frequency * Double(harmonic)
                let gain = (1.0 / pow(Double(harmonic), 1.25)) * bodyGain(harmonicFrequency)
                value += gain * sin(phase * Double(harmonic) + Double(harmonic) * 0.15)
            }
            // Souffle d'archet très bref à l'attaque, déterministe.
            let bowNoise = (sin(phase * 7.13) + sin(phase * 11.7)) * 0.5
                * max(0, 1 - progress * 9) * 0.05
            value += bowNoise
            samples[startIndex + offset] += Float(value * envelope * amplitude / 2.2)
        }
    }

    /// Résonances grossières de la caisse du violoncelle (corps + table).
    private static func bodyGain(_ frequency: Double) -> Double {
        let modes: [(center: Double, gain: Double, width: Double)] = [
            (260, 0.55, 90),
            (520, 0.35, 120),
            (1250, 0.25, 250),
            (2800, 0.12, 500)
        ]
        var gain = 0.45
        for mode in modes {
            let distance = (frequency - mode.center) / mode.width
            gain += mode.gain * exp(-distance * distance)
        }
        return gain
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

/// Génère un extrait MusicXML monophonique à partir d'un moment de replay.
/// Sert à afficher une **portée gravée** (swift-sheet-music) sans dépendre du
/// fichier source complet : les notes, mesures, durées et articulations du
/// moment sont ré-encodées dans un fragment propre.
enum ReplayStaffXML {
    static func musicXML(for moment: ReplayMoment) -> Data? {
        let notes = moment.notes.filter { $0.midi >= 0 && $0.midi <= 127 }
        guard !notes.isEmpty else { return nil }

        let groups = Dictionary(grouping: notes) { note in
            note.measure > 0 ? note.measure : 1
        }
        let measureKeys = groups.keys.sorted()
        guard !measureKeys.isEmpty else { return nil }

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <work><work-title>Replay</work-title></work>
          <identification><encoding><software>OpenCello</software></encoding></identification>
          <part-list><score-part id="P1"><part-name>Cello</part-name></score-part></part-list>
          <part id="P1">

        """

        for (index, key) in measureKeys.enumerated() {
            let measureNotes = (groups[key] ?? []).sorted {
                if $0.beat != $1.beat { return $0.beat < $1.beat }
                return $0.onset < $1.onset
            }
            xml += "    <measure number=\"\(key)\">\n"
            if index == 0 {
                xml += """
                      <attributes>
                        <divisions>4</divisions>
                        <key><fifths>0</fifths></key>
                        <time><beats>4</beats><beat-type>4</beat-type></time>
                        <clef><sign>F</sign><line>4</line></clef>
                      </attributes>

                """
            }

            var cursor = 0
            for note in measureNotes {
                let beat = max(1, note.beat)
                let start = max(cursor, min(15, Int(((beat - 1) * 4).rounded())))
                if start > cursor {
                    xml += "      <forward><duration>\(start - cursor)</duration></forward>\n"
                }

                let duration = max(0.06, note.expectedDuration ?? note.duration)
                let notation = notatedDuration(duration)
                let divisions = notation.divisions
                let pitch = pitchParts(for: note.midi)
                xml += "      <note>\n"
                xml += "        <pitch><step>\(pitch.step)</step>"
                if pitch.alter != 0 {
                    xml += "<alter>\(pitch.alter)</alter>"
                }
                xml += "<octave>\(pitch.octave)</octave></pitch>\n"
                xml += "        <duration>\(divisions)</duration>\n"
                xml += "        <voice>1</voice>\n"
                xml += "        <type>\(notation.type)</type>\n"
                if notation.dotted {
                    xml += "        <dot/>\n"
                }
                if let articulation = note.scoreArticulation {
                    let tag = articulationTag(articulation)
                    if let tag {
                        xml += "        <notations><\(tag)/></notations>\n"
                    }
                }
                xml += "      </note>\n"
                cursor = max(cursor, start + divisions)
            }
            xml += "    </measure>\n"
        }

        xml += """
          </part>
        </score-partwise>
        """
        return Data(xml.utf8)
    }

    private static func pitchParts(for midi: Int) -> (step: String, alter: Int, octave: Int) {
        let names = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
        let alters = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]
        let pitchClass = ((midi % 12) + 12) % 12
        let octave = midi / 12 - 1
        return (names[pitchClass], alters[pitchClass], octave)
    }

    private static func notatedDuration(_ seconds: Double) -> (divisions: Int, type: String, dotted: Bool) {
        // À 120 BPM : 1 temps = 0,5 s ; divisions = 4 par temps.
        let beats = max(0.25, seconds * 2)
        let options: [(beats: Double, divisions: Int, type: String, dotted: Bool)] = [
            (4.0, 16, "whole", false),
            (3.0, 12, "half", true),
            (2.0, 8, "half", false),
            (1.5, 6, "quarter", true),
            (1.0, 4, "quarter", false),
            (0.75, 3, "eighth", true),
            (0.5, 2, "eighth", false),
            (0.25, 1, "16th", false)
        ]
        let best = options.min { abs($0.beats - beats) < abs($1.beats - beats) } ?? options[4]
        return (best.divisions, best.type, best.dotted)
    }

    private static func articulationTag(_ articulation: String) -> String? {
        switch articulation.lowercased() {
        case "staccato": return "staccato"
        case "accent": return "accent"
        case "tenuto": return "tenuto"
        case "marcato": return "strong-accent"
        case "spiccato": return "staccato"
        default: return nil
        }
    }
}

@MainActor
final class ReplayAudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var instrumentName = "Violoncelle (Apple DLS)"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampler = AVAudioUnitSampler()
    private let instrumentMixer = AVAudioMixerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 2)
    private let reverb = AVAudioUnitReverb()
    private let sampleRate = ReplaySynth.defaultSampleRate
    private var sequencer: AVAudioSequencer?
    private var configured = false
    private var samplerReady = false
    private var finishWork: DispatchWorkItem?

    private static let replayBPM = 120.0
    private static let celloProgram: UInt8 = 42
    private static let maxChannels = 8
    private static let dlsURL = URL(
        fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
    )

    func play(moment: ReplayMoment, corrected: Bool) {
        stop()
        configureIfNeeded()
        if samplerReady, playWithSampler(moment: moment, corrected: corrected) {
            return
        }
        playPCM(moment: moment, corrected: corrected)
    }

    func stop() {
        finishWork?.cancel()
        finishWork = nil
        sequencer?.stop()
        sequencer = nil
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
    }

    // MARK: - Configuration

    private func configureIfNeeded() {
        guard !configured else { return }
        engine.attach(player)
        engine.attach(sampler)
        engine.attach(instrumentMixer)
        engine.attach(eq)
        engine.attach(reverb)

        // Chaîne : instrument → EQ de caisse → réverbération de salle → mixage.
        if let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) {
            engine.connect(player, to: instrumentMixer, format: format)
        }
        engine.connect(sampler, to: instrumentMixer, format: nil)
        engine.connect(instrumentMixer, to: eq, format: nil)
        engine.connect(eq, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        let low = eq.bands[0]
        low.filterType = .lowShelf
        low.frequency = 220
        low.gain = 2.0
        let high = eq.bands[1]
        high.filterType = .highShelf
        high.frequency = 3200
        high.gain = -1.5
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 14

        configured = true
        loadInstrument()
    }

    /// Priorité à un SoundFont personnel (cello.sf2), sinon le violoncelle
    /// General MIDI fourni par macOS. Aucun échantillon commercial n'est
    /// embarqué : les grandes bibliothèques du marché sont sous licence.
    private func loadInstrument() {
        if let soundFont = Self.userSoundFontURL {
            do {
                try sampler.loadSoundBankInstrument(
                    at: soundFont,
                    program: Self.celloProgram,
                    bankMSB: 0,
                    bankLSB: 0
                )
                samplerReady = true
                sampler.overallGain = 6
                instrumentName = "SoundFont personnel (cello.sf2)"
                return
            } catch {
                // Repli sur le DLS système.
            }
        }

        do {
            try sampler.loadInstrument(at: Self.dlsURL)
            sampler.sendProgramChange(
                Self.celloProgram,
                bankMSB: 0,
                bankLSB: 0,
                onChannel: 0
            )
            samplerReady = true
            sampler.overallGain = 6
            instrumentName = "Violoncelle Apple DLS (GM 42)"
        } catch {
            samplerReady = false
            instrumentName = "Synthèse PCM de secours"
        }
    }

    private static var userSoundFontURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let url = base
            .appendingPathComponent("OpenCello", isDirectory: true)
            .appendingPathComponent("Instruments", isDirectory: true)
            .appendingPathComponent("cello.sf2")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Lecture par échantillonneur (violoncelle)

    private func playWithSampler(moment: ReplayMoment, corrected: Bool) -> Bool {
        let notes = moment.notes.sorted { $0.onset < $1.onset }
        guard !notes.isEmpty else { return false }

        let sequence = AVAudioSequencer(audioEngine: engine)
        let track = sequence.createAndAppendTrack()
        track.destinationAudioUnit = sampler
        sequence.tempoTrack.addEvent(
            AVExtendedTempoEvent(tempo: Self.replayBPM),
            at: 0
        )

        for channel in 0..<Self.maxChannels {
            track.addEvent(
                AVMIDIProgramChangeEvent(
                    channel: UInt32(channel),
                    programNumber: UInt32(Self.celloProgram)
                ),
                at: 0
            )
        }

        let secondsPerBeat = 60 / Self.replayBPM
        let base = notes.map(\.onset).min() ?? 0
        var endSeconds = 0.0

        for (index, note) in notes.enumerated() {
            let channel = UInt32(index % Self.maxChannels)
            let start = max(0, (corrected ? note.onset : note.onset + note.rhythmMs / 1000) - base)
            var duration = corrected ? (note.expectedDuration ?? note.duration) : note.duration
            if corrected {
                duration *= ReplaySynth.articulationFactor(note.scoreArticulation)
            }
            duration = max(0.06, duration)

            let velocity = UInt32(max(1, min(127, note.velocity ?? 90)))
            let key = UInt32(max(0, min(127, note.midi)))
            let startBeat = start / secondsPerBeat
            let durationBeats = duration / secondsPerBeat

            let cents = corrected ? 0 : max(-200, min(200, note.cents))
            let bend = UInt32(max(0, min(16383, Int(8192 + cents / 200 * 8192))))
            track.addEvent(
                AVMIDIPitchBendEvent(channel: channel, value: bend),
                at: max(0, startBeat - 0.002)
            )
            track.addEvent(
                AVMIDINoteEvent(
                    channel: channel,
                    key: key,
                    velocity: velocity,
                    duration: durationBeats
                ),
                at: startBeat
            )
            track.addEvent(
                AVMIDIPitchBendEvent(channel: channel, value: 8192),
                at: startBeat + durationBeats + 0.01
            )

            endSeconds = max(endSeconds, start + duration)
        }

        do {
            try engine.start()
            try sequence.start()
        } catch {
            return false
        }

        sequencer = sequence
        isPlaying = true
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        finishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + endSeconds + 0.25, execute: work)
        return true
    }

    // MARK: - Repli PCM

    private func playPCM(moment: ReplayMoment, corrected: Bool) {
        let samples = ReplaySynth.render(moment: moment, corrected: corrected, sampleRate: sampleRate)
        guard !samples.isEmpty, let buffer = makeBuffer(samples) else { return }
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
