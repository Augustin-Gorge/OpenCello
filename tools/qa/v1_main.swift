import Foundation

@main
struct V1Test {
    static func main() async {
        await MainActor.run {
            print("EXERCISES:", ExerciseCatalog.all.count)
            let recommendations = ExerciseCatalog.recommendations(for: ["B1", "A1"])
            print("RECOMMENDATIONS:", recommendations.map(\.id).joined(separator: ","))

            let hand = HandRecord(
                frames: 100,
                validFrames: 90,
                meanAngleDegrees: 14,
                meanSignedAngleDegrees: 14,
                maxAngleDegrees: 22,
                meanFingerSpeed: 1.7,
                meanPresserConfidence: 0.6,
                thumbHypothesisRatio: 0.2,
                rules: [
                    HandRuleRecord(ruleID: "A17", title: "Main gauche cassée", seconds: 8, occurrences: 2, confidence: nil),
                    HandRuleRecord(ruleID: "A18", title: "Pouce gauche crispé (hypothèse)", seconds: 5, occurrences: 1, confidence: "hypothèse")
                ]
            )
            let note = NotePositionRecord(
                scoreIndex: 0,
                measure: 1,
                beat: 1,
                expectedMidi: 60,
                playedMidi: 60,
                cents: -18,
                rhythmMs: 40,
                onset: 0,
                duration: 0.4,
                position: 2,
                finger: 1,
                fromPosition: 1,
                fromFinger: nil,
                direction: "montée",
                confidence: 0.7,
                isShift: true,
                glideMs: 120,
                glideSlope: 300,
                isVoluntaryGlide: false,
                contour: [-20, -10, 0],
                articulation: "détaché"
            )
            let stats = PositionStatsRecord(
                samples: [note],
                shiftCount: 1,
                meanArrivalCents: -18,
                meanShiftDurationMs: 120,
                parasiteGlides: 0,
                voluntaryGlides: 0
            )
            let technique = TechniqueRecord(
                piqueNotes: 4,
                piqueUnevenRuns: 0,
                piqueMeanDurationCV: 0.05,
                piqueMeanEnergyCV: 0.04,
                piqueWorstIndex: nil,
                piqueWorstDeviation: nil,
                glideShifts: 1,
                parasiteGlides: 0,
                voluntaryGlides: 0,
                meanGlideMs: 120,
                meanGlideSlope: 300
            )
            let replay = ReplayMoment(
                kind: "Justesse",
                title: "Justesse — mesure 1",
                detail: "-18 cents sur la note attendue",
                advice: "Isole cette note et vérifie le doigt.",
                measure: 1,
                beat: 1,
                scoreIndex: 0,
                expectedMidi: 60,
                cents: -18,
                rhythmMs: 40,
                glideMs: 120,
                position: 2,
                finger: 1,
                notes: [
                    ReplayNote(scoreIndex: 0, measure: 1, beat: 1, midi: 60, onset: 0, duration: 0.4, cents: -18, contour: [-20, -10, 0], rhythmMs: 40)
                ]
            )

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
                bow: BowRecord(frames: 100, goodAngle: 82, goodZone: 74),
                hand: hand,
                positionStats: stats,
                technique: technique,
                replayMoments: [replay],
                reportMarkdown: "# Test"
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

            // Statistiques (Accelerate/vDSP)
            let mean = StatsKit.mean([2, 4, 6]) ?? -1
            let std = StatsKit.standardDeviation([2, 4, 6]) ?? -1
            let slope = StatsKit.linearSlope(x: [0, 1, 2], y: [0, 2, 4]) ?? -1
            let moving = StatsKit.movingAverage([1, 3, 5, 7], window: 3)
            print("STATS:", mean, String(format: "%.3f", std), slope, moving.count == 4)

            // Score de séance + commentaires + profil
            let score = SessionScore.compute(for: record)
            print("SCORE:", score.total, score.tierLabel)
            let commentary = ReportCommentary.build(for: record, previous: nil, settings: AppSettings())
            print("COMMENTARY:", commentary.global.count > 10, "posture:", commentary.posture.count, "exercices:", commentary.exercises.map(\.id).joined(separator: ","))
            let profile = ProfileSummary.compute(records: [record])
            print("PROFILE:", profile.sessionCount, profile.currentStreak, profile.averageScore ?? -1, profile.trends.count)

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
