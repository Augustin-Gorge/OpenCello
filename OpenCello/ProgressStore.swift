import Foundation
import Combine

struct PostureRecord: Codable, Identifiable {
    let ruleID: String
    let title: String
    let seconds: Double
    let occurrences: Int

    var id: String { ruleID }
}

struct PieceRecord: Codable {
    let title: String
    let matched: Int
    let total: Int
    let inTune: Int
    let meanAbsCents: Double
    let meanAbsRhythmMs: Double
    let outOfScore: Int
    let estimatedTempo: Double?
}

struct BowRecord: Codable {
    let frames: Int
    let goodAngle: Int
    let goodZone: Int
}

// MARK: - Main gauche, positions et techniques (v1.1)

struct HandRuleRecord: Codable, Identifiable {
    let ruleID: String
    let title: String
    let seconds: Double
    let occurrences: Int
    let confidence: String?

    var id: String { ruleID }
}

struct HandRecord: Codable {
    let frames: Int
    let validFrames: Int
    let meanAngleDegrees: Double?
    let meanSignedAngleDegrees: Double?
    let maxAngleDegrees: Double?
    let meanFingerSpeed: Double?
    let meanPresserConfidence: Double?
    let thumbHypothesisRatio: Double?
    let rules: [HandRuleRecord]
    /// Frames où une main a été détectée (même si l'angle n'était pas mesurable).
    /// Optionnel pour rester compatible avec les enregistrements déjà écrits.
    var detectedFrames: Int? = nil

    var detectionRate: Double? {
        guard frames > 0 else { return nil }
        return Double(detectedFrames ?? validFrames) / Double(frames)
    }
}

/// Une note avec sa position et son doigt estimés. Les champs de partition
/// sont optionnels : la même structure sert en séance libre et en mode morceau.
struct NotePositionRecord: Codable, Identifiable {
    let scoreIndex: Int?
    let measure: Int?
    let beat: Double?
    let expectedMidi: Int?
    let playedMidi: Int
    let cents: Double
    let rhythmMs: Double?
    let onset: Double
    let duration: Double
    let position: Int?
    let finger: Int?
    let fromPosition: Int?
    let fromFinger: Int?
    let direction: String?
    let confidence: Double
    let isShift: Bool
    let glideMs: Double?
    let glideSlope: Double?
    let isVoluntaryGlide: Bool
    let contour: [Double]
    let articulation: String?
    /// Durée attendue en secondes d'après le MusicXML (pour la version corrigée).
    var expectedDuration: Double? = nil
    /// Nuance écrite convertie en vélocité MIDI.
    var velocity: Int? = nil
    /// Articulation écrite dans la partition (staccato, accent, legato…).
    var scoreArticulation: String? = nil
    /// Corde estimée/jouée : 1 = la, 2 = ré, 3 = sol, 4 = do.
    var stringNumber: Int? = nil
    /// Corde écrite dans le MusicXML, si présente.
    var expectedStringNumber: Int? = nil
    /// Vrai si la position est déduite exactement (note + doigt + corde).
    var exactPosition: Bool = false
    /// Vrai si le pouce joue (position du pouce, registre aigu).
    var isThumbPosition: Bool = false

    var id: String {
        "\(scoreIndex ?? -1)-\(String(format: "%.3f", onset))"
    }

    var fingerText: String {
        guard let finger else { return "doigté non mesuré" }
        switch finger {
        case 0: return "corde à vide"
        case 5: return "pouce"
        default: return "\(finger)e doigt"
        }
    }

    var positionText: String {
        guard let position else { return "position non mesurée" }
        return isThumbPosition ? "position du pouce \(position)e" : "\(position)e position"
    }
}

struct PositionStatsRecord: Codable {
    let samples: [NotePositionRecord]
    let shiftCount: Int
    let meanArrivalCents: Double?
    let meanShiftDurationMs: Double?
    let parasiteGlides: Int
    let voluntaryGlides: Int

    var pieceNotes: [NotePositionRecord] {
        samples.filter { $0.scoreIndex != nil }
    }

    var shiftSamples: [NotePositionRecord] {
        samples.filter(\.isShift)
    }
}

struct TechniqueRecord: Codable {
    let piqueNotes: Int
    let piqueUnevenRuns: Int
    let piqueMeanDurationCV: Double?
    let piqueMeanEnergyCV: Double?
    let piqueWorstIndex: Int?
    let piqueWorstDeviation: Double?
    let glideShifts: Int
    let parasiteGlides: Int
    let voluntaryGlides: Int
    let meanGlideMs: Double?
    let meanGlideSlope: Double?

    /// 0 = très inégal, 1 = parfaitement égal. Basé sur le coefficient de
    /// variation des durées (seuil pédagogique 12 %).
    var piqueRegularity: Double? {
        guard let cv = piqueMeanDurationCV else { return nil }
        return max(0, min(1, 1 - cv / 0.25))
    }

    var parasiteGlideRatio: Double? {
        let total = parasiteGlides + voluntaryGlides
        guard total > 0 else { return nil }
        return Double(parasiteGlides) / Double(total)
    }
}

// MARK: - Replay pédagogique (indices + statistiques, aucun audio brut)

struct ReplayNote: Codable, Identifiable {
    let scoreIndex: Int
    let measure: Int
    let beat: Double
    let midi: Int
    let onset: Double
    let duration: Double
    let cents: Double
    let contour: [Double]
    let rhythmMs: Double
    /// Durée attendue (MusicXML) en secondes ; nil = durée jouée.
    var expectedDuration: Double? = nil
    var velocity: Int? = nil
    var scoreArticulation: String? = nil

    var id: Int { scoreIndex }
}

struct ReplayMoment: Codable, Identifiable {
    let id: UUID
    let kind: String
    let title: String
    let detail: String
    let advice: String
    let measure: Int?
    let beat: Double?
    let scoreIndex: Int?
    let expectedMidi: Int?
    let cents: Double?
    let rhythmMs: Double?
    let glideMs: Double?
    let position: Int?
    let finger: Int?
    let notes: [ReplayNote]

    init(
        id: UUID = UUID(),
        kind: String,
        title: String,
        detail: String,
        advice: String,
        measure: Int? = nil,
        beat: Double? = nil,
        scoreIndex: Int? = nil,
        expectedMidi: Int? = nil,
        cents: Double? = nil,
        rhythmMs: Double? = nil,
        glideMs: Double? = nil,
        position: Int? = nil,
        finger: Int? = nil,
        notes: [ReplayNote]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.advice = advice
        self.measure = measure
        self.beat = beat
        self.scoreIndex = scoreIndex
        self.expectedMidi = expectedMidi
        self.cents = cents
        self.rhythmMs = rhythmMs
        self.glideMs = glideMs
        self.position = position
        self.finger = finger
        self.notes = notes
    }
}

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let mode: String
    let title: String
    let duration: Double
    let posture: [PostureRecord]
    let noteCount: Int
    let inTuneNotes: Int
    let meanAbsCents: Double
    let meanStability: Double
    let soundingSeconds: Double
    let noteCents: [Double]
    let noteStability: [Double]
    let piece: PieceRecord?
    var bow: BowRecord? = nil

    // Statistiques complémentaires (optionnelles : compatible avec l'historique v1.0).
    var meanHNR: Double? = nil
    var meanCentroid: Double? = nil
    var meanRMSVariation: Double? = nil
    var postureDetectionRate: Double? = nil
    var medianFrequency: Double? = nil
    var validPitchFrames: Int? = nil
    var pitchFrames: Int? = nil
    var articulationCounts: [String: Int]? = nil
    var meanVibratoRate: Double? = nil
    var meanVibratoExtent: Double? = nil
    // Phase 7 (v1.1) : main gauche, positions/déplacements, techniques, replays.
    var hand: HandRecord? = nil
    var positionStats: PositionStatsRecord? = nil
    var technique: TechniqueRecord? = nil
    var replayMoments: [ReplayMoment]? = nil
    // Ancien champ Markdown : conservé uniquement pour relire l'historique v1.0.
    var reportMarkdown: String? = nil

    /// Décodage manuel (dans l'extension ci-dessous) : les champs optionnels
    /// ajoutés après la v1.0 doivent être lus avec `decodeIfPresent`.
    var inTuneRatio: Double {
        noteCount > 0 ? Double(inTuneNotes) / Double(noteCount) : 0
    }

    /// Somme du temps en alerte sur toutes les règles de posture.
    var totalPostureSeconds: Double {
        posture.reduce(0) { $0 + $1.seconds }
    }

    /// Part de la séance passée en alerte posture (0-1).
    var alertRatio: Double {
        duration > 0 ? min(1, totalPostureSeconds / duration) : 0
    }

    /// Part de la séance avec du son (0-1).
    var soundingRatio: Double {
        duration > 0 ? min(1, soundingSeconds / duration) : 0
    }

    /// Notes du mode morceau avec leur contexte de partition (pour les replays).
    var pieceNotes: [NotePositionRecord] {
        positionStats?.pieceNotes ?? []
    }

    /// Notes qui suivent un déplacement (pour la matrice doigt × position).
    var shiftNotes: [NotePositionRecord] {
        positionStats?.shiftSamples ?? []
    }
}

extension SessionRecord {
    /// Décodage manuel : les champs optionnels ajoutés après la v1.0 ont des
    /// valeurs par défaut et doivent être lus avec `decodeIfPresent` (le
    /// décodage synthétisé les ignorerait à cause des valeurs initiales).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        mode = try container.decode(String.self, forKey: .mode)
        title = try container.decode(String.self, forKey: .title)
        duration = try container.decode(Double.self, forKey: .duration)
        posture = try container.decode([PostureRecord].self, forKey: .posture)
        noteCount = try container.decode(Int.self, forKey: .noteCount)
        inTuneNotes = try container.decode(Int.self, forKey: .inTuneNotes)
        meanAbsCents = try container.decode(Double.self, forKey: .meanAbsCents)
        meanStability = try container.decode(Double.self, forKey: .meanStability)
        soundingSeconds = try container.decode(Double.self, forKey: .soundingSeconds)
        noteCents = try container.decode([Double].self, forKey: .noteCents)
        noteStability = try container.decode([Double].self, forKey: .noteStability)
        piece = try container.decodeIfPresent(PieceRecord.self, forKey: .piece)
        bow = try container.decodeIfPresent(BowRecord.self, forKey: .bow)
        meanHNR = try container.decodeIfPresent(Double.self, forKey: .meanHNR)
        meanCentroid = try container.decodeIfPresent(Double.self, forKey: .meanCentroid)
        meanRMSVariation = try container.decodeIfPresent(Double.self, forKey: .meanRMSVariation)
        postureDetectionRate = try container.decodeIfPresent(Double.self, forKey: .postureDetectionRate)
        medianFrequency = try container.decodeIfPresent(Double.self, forKey: .medianFrequency)
        validPitchFrames = try container.decodeIfPresent(Int.self, forKey: .validPitchFrames)
        pitchFrames = try container.decodeIfPresent(Int.self, forKey: .pitchFrames)
        articulationCounts = try container.decodeIfPresent([String: Int].self, forKey: .articulationCounts)
        meanVibratoRate = try container.decodeIfPresent(Double.self, forKey: .meanVibratoRate)
        meanVibratoExtent = try container.decodeIfPresent(Double.self, forKey: .meanVibratoExtent)
        hand = try container.decodeIfPresent(HandRecord.self, forKey: .hand)
        positionStats = try container.decodeIfPresent(PositionStatsRecord.self, forKey: .positionStats)
        technique = try container.decodeIfPresent(TechniqueRecord.self, forKey: .technique)
        replayMoments = try container.decodeIfPresent([ReplayMoment].self, forKey: .replayMoments)
        reportMarkdown = try container.decodeIfPresent(String.self, forKey: .reportMarkdown)
    }
}

/// Historique local des séances + suivi des exercices terminés.
final class ProgressStore: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []
    @Published private(set) var completedExercises: Set<String> = []

    private let defaults = UserDefaults.standard
    private let completedKey = "progress.completedExercises"
    private let fileURL: URL?

    init(baseDirectory: URL? = nil) {
        let fileManager = FileManager.default
        let directory: URL?
        if let baseDirectory {
            directory = baseDirectory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            directory = base?.appendingPathComponent("OpenCello", isDirectory: true)
        }
        if let directory {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        fileURL = directory?.appendingPathComponent("history.json")

        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
        }
        completedExercises = Set(defaults.stringArray(forKey: completedKey) ?? [])
    }

    func add(_ record: SessionRecord) {
        records.insert(record, at: 0)
        if records.count > 200 {
            records.removeLast(records.count - 200)
        }
        save()
    }

    func isCompleted(_ exerciseID: String) -> Bool {
        completedExercises.contains(exerciseID)
    }

    func markExercise(_ exerciseID: String, completed: Bool) {
        if completed {
            completedExercises.insert(exerciseID)
        } else {
            completedExercises.remove(exerciseID)
        }
        defaults.set(Array(completedExercises).sorted(), forKey: completedKey)
    }

    private func save() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(records) {
            try? data.write(to: fileURL)
        }
    }
}
