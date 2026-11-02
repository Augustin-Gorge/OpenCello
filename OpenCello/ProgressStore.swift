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
    let reportMarkdown: String
    var bow: BowRecord? = nil

    var inTuneRatio: Double {
        noteCount > 0 ? Double(inTuneNotes) / Double(noteCount) : 0
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
