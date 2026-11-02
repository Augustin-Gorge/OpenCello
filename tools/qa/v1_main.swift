import Foundation

@main
struct V1Test {
    static func main() async {
        await MainActor.run {
            print("EXERCISES:", ExerciseCatalog.all.count)
            let recommendations = ExerciseCatalog.recommendations(for: ["B1", "A1"])
            print("RECOMMENDATIONS:", recommendations.map(\.id).joined(separator: ","))

            let record = SessionRecord(
                id: UUID(),
                date: Date(),
                mode: "Séance libre",
                title: "Test",
                duration: 600,
                posture: [PostureRecord(ruleID: "A1", title: "Tête en avant", seconds: 12, occurrences: 3)],
                noteCount: 10,
                inTuneNotes: 7,
                meanAbsCents: 18.5,
                meanStability: 9.2,
                soundingSeconds: 420,
                noteCents: [-20, 10, 30, -5, 12, 0, 25, -15, 8, 3],
                noteStability: [8, 9, 10, 7, 11, 6, 9, 8, 10, 7],
                piece: nil,
                reportMarkdown: "# Test",
                bow: BowRecord(frames: 100, goodAngle: 82, goodZone: 74)
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            guard let data = try? encoder.encode(record),
                  let decoded = try? decoder.decode(SessionRecord.self, from: data) else {
                print("RECORD ROUNDTRIP: FAILED")
                return
            }
            print("RECORD ROUNDTRIP:", decoded.id == record.id, "notes:", decoded.noteCents.count)
            print(
                "ACCURACY:",
                NoteAccuracy.evaluate(cents: 10, tolerance: 25).label,
                NoteAccuracy.evaluate(cents: 40, tolerance: 25).label,
                NoteAccuracy.evaluate(cents: 80, tolerance: 25).label
            )

            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("opencello-test-\(UUID().uuidString)", isDirectory: true)
            let store = ProgressStore(baseDirectory: tempDirectory)
            store.add(record)
            let reloaded = ProgressStore(baseDirectory: tempDirectory)
            print("HISTORY:", reloaded.records.count == 1, reloaded.records.first?.title ?? "-")
            try? FileManager.default.removeItem(at: tempDirectory)

            if let url = ReportExporter.exportPDF(record) {
                print("PDF:", url.path, "exists:", FileManager.default.fileExists(atPath: url.path))
                if ProcessInfo.processInfo.environment["KEEP_PDF"] != "1" {
                    try? FileManager.default.removeItem(at: url)
                }
            } else {
                print("PDF: FAILED")
            }

            if let pack = ReportExporter.exportTeacherPack(record) {
                let files = (try? FileManager.default.contentsOfDirectory(atPath: pack.path)) ?? []
                print("TEACHER PACK:", files.sorted().joined(separator: ","))
                try? FileManager.default.removeItem(at: pack)
            } else {
                print("TEACHER PACK: FAILED")
            }

            if let url = ReportExporter.exportAnonymized([record]) {
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                print("ANON:", FileManager.default.fileExists(atPath: url.path), "containsTitle:", text.contains("Test"))
                try? FileManager.default.removeItem(at: url)
            } else {
                print("ANON: FAILED")
            }
        }
    }
}
