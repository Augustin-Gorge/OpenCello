import Foundation

struct FollowFeedback {
    var matched = false
    var scoreIndex: Int?
    var expectedMidi: Int?
    var expectedName = "—"
    var detectedName = "—"
    var cents: Double?
    var rhythmMs: Double?
    var measure: Int?
    var beat: Double?
    var expectedDurationBeats: Double?
    var expectedGlissando = false
    var expectedVelocity: Int?
    var expectedArticulation: String?
    var progress: Double = 0
    var message = ""
    var isInTune = false
    var isOnTime = false
}

struct PieceStats {
    var totalNotes = 0
    var matched = 0
    var inTune = 0
    var sumAbsCents = 0.0
    var sumAbsRhythmMs = 0.0
    var rhythmSamples = 0
    var outOfScore = 0
    var estimatedTempo: Double?
    var startedAt: Date?

    var meanAbsCents: Double {
        matched > 0 ? sumAbsCents / Double(matched) : 0
    }

    var inTuneRatio: Double {
        matched > 0 ? Double(inTune) / Double(matched) : 0
    }

    var meanAbsRhythmMs: Double {
        rhythmSamples > 0 ? sumAbsRhythmMs / Double(rhythmSamples) : 0
    }
}

/// Suivi de partition en ligne : associe chaque note entendue à une note attendue
/// (fenêtre locale + pénalité de saut), calcule l'écart en cents et l'écart rythmique
/// par rapport à une grille au tempo choisi, et ré-ancre en cas de saut.
final class ScoreFollower {
    let title: String
    let bpm: Double

    private let notes: [ScoreNote]
    private var position = 0
    private var anchorActual: TimeInterval?
    private var anchorScoreBeats: Double = 0
    private var lastOnset: TimeInterval?
    private var lastScoreBeats: Double = 0
    private var tempoEstimate: Double?
    private var consecutiveMisses = 0
    private var recentMidis: [Int] = []
    private(set) var stats = PieceStats()

    init(score: Score, partIndex: Int, bpm: Double) {
        self.title = score.title
        self.bpm = max(30, min(240, bpm))
        let part: ScorePart
        if score.parts.indices.contains(partIndex) {
            part = score.parts[partIndex]
        } else {
            part = score.parts.first ?? ScorePart(name: "", notes: [])
        }
        self.notes = part.notes.sorted { $0.onsetBeats < $1.onsetBeats }
        stats.totalNotes = notes.count
        stats.startedAt = Date()
    }

    var noteCount: Int { notes.count }

    func note(at index: Int) -> ScoreNote? {
        guard notes.indices.contains(index) else { return nil }
        return notes[index]
    }

    func notes(around index: Int, radius: Int = 2) -> [ScoreNote] {
        let lower = max(0, index - radius)
        let upper = min(notes.count - 1, index + radius)
        guard lower <= upper else { return [] }
        return Array(notes[lower...upper])
    }

    /// Notes voisines avec leur index d'origine (pour les replays).
    func indexedNotes(around index: Int, radius: Int = 4) -> [(index: Int, note: ScoreNote)] {
        let lower = max(0, index - radius)
        let upper = min(notes.count - 1, index + radius)
        guard lower <= upper else { return [] }
        return (lower...upper).map { ($0, notes[$0]) }
    }

    func process(midi: Double, onset: TimeInterval) -> FollowFeedback {
        var feedback = FollowFeedback()
        feedback.detectedName = NoteNamer.name(forMidi: Int(midi.rounded()))
        feedback.progress = notes.isEmpty ? 0 : Double(position) / Double(notes.count)

        guard !notes.isEmpty else {
            feedback.message = "Partition vide."
            return feedback
        }

        let windowEnd = min(position + 8, notes.count)
        var bestIndex: Int?
        var bestCost = Double.greatestFiniteMagnitude

        if position < windowEnd {
            for index in position..<windowEnd {
                let expected = Double(notes[index].midi)
                let pitchDifference = abs(midi - expected)
                let skipPenalty = Double(index - position) * 0.45
                let cost = pitchDifference + skipPenalty
                if cost < bestCost {
                    bestCost = cost
                    bestIndex = index
                }
            }
        }

        guard let index = bestIndex, bestCost <= 2.4 else {
            consecutiveMisses += 1
            stats.outOfScore += 1
            recentMidis.append(Int(midi.rounded()))
            if recentMidis.count > 4 { recentMidis.removeFirst() }
            if consecutiveMisses >= 3 { relocate() }
            feedback.message = "Note hors partition (ou saut de mesure)."
            return feedback
        }

        let expected = notes[index]
        let cents = (midi - Double(expected.midi)) * 100
        feedback.matched = true
        feedback.scoreIndex = index
        feedback.expectedMidi = expected.midi
        feedback.expectedName = NoteNamer.name(forMidi: expected.midi)
        feedback.cents = cents
        feedback.measure = expected.measureIndex
        feedback.beat = max(1, expected.onsetBeats - expected.measureStartBeats + 1)
        feedback.expectedDurationBeats = expected.durationBeats
        feedback.expectedGlissando = expected.glissando
        feedback.expectedVelocity = expected.velocity
        feedback.expectedArticulation = expected.scoreArticulation
        feedback.isInTune = abs(cents) <= 25

        if anchorActual == nil {
            anchorActual = onset
            anchorScoreBeats = expected.onsetBeats
        }
        let expectedOnset = (anchorActual ?? onset) + (expected.onsetBeats - anchorScoreBeats) * 60 / bpm
        let rhythmMs = (onset - expectedOnset) * 1000
        feedback.rhythmMs = rhythmMs
        feedback.isOnTime = abs(rhythmMs) <= 120

        if let previousOnset = lastOnset {
            let deltaTime = onset - previousOnset
            let deltaBeats = expected.onsetBeats - lastScoreBeats
            if deltaTime > 0.05, deltaBeats > 0 {
                let instantTempo = 60 * deltaBeats / deltaTime
                if instantTempo > 30, instantTempo < 240 {
                    tempoEstimate = tempoEstimate.map { $0 * 0.8 + instantTempo * 0.2 } ?? instantTempo
                    stats.estimatedTempo = tempoEstimate
                }
            }
        }

        lastOnset = onset
        lastScoreBeats = expected.onsetBeats
        position = min(index + 1, notes.count)
        consecutiveMisses = 0
        recentMidis.append(Int(midi.rounded()))
        if recentMidis.count > 4 { recentMidis.removeFirst() }

        stats.matched += 1
        stats.sumAbsCents += abs(cents)
        if abs(cents) <= 25 { stats.inTune += 1 }
        stats.sumAbsRhythmMs += abs(rhythmMs)
        stats.rhythmSamples += 1

        feedback.progress = notes.isEmpty ? 1 : Double(position) / Double(notes.count)
        feedback.message = message(cents: cents, rhythmMs: rhythmMs)
        return feedback
    }

    private func message(cents: Double, rhythmMs: Double) -> String {
        if abs(cents) > 50 {
            return "Justesse : \(Int(cents.rounded())) cents — ajustez la main gauche."
        }
        if abs(rhythmMs) > 200 {
            return rhythmMs > 0
                ? "Rythme : en retard de \(Int(abs(rhythmMs))) ms."
                : "Rythme : en avance de \(Int(abs(rhythmMs))) ms."
        }
        if abs(cents) <= 25, abs(rhythmMs) <= 120 {
            return "Juste et en place ✅"
        }
        return "Bien — continuez."
    }

    private func relocate() {
        guard recentMidis.count >= 2 else { return }
        let target = recentMidis.map { (($0 % 12) + 12) % 12 }

        for start in 0..<notes.count {
            if start + target.count > notes.count { break }
            var matches = true
            for offset in 0..<target.count {
                let pitchClass = ((notes[start + offset].midi % 12) + 12) % 12
                if pitchClass != target[offset] {
                    matches = false
                    break
                }
            }
            if matches {
                position = start + target.count
                consecutiveMisses = 0
                return
            }
        }
    }
}
