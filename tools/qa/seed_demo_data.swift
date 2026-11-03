import Foundation

// Outil de démonstration : génère un historique réaliste de séances (4 semaines,
// progression visible) et l'écrit dans history.json pour tester l'UI
// (onglets Rapports et Profil). RNG déterministe → données reproductibles.
//
// Usage :
//   swiftc -O -o build/qa/seed_demo OpenCello/ProgressStore.swift tools/qa/seed_demo_data.swift
//   ./build/qa/seed_demo            # écrit dans ~/Library/Application Support/OpenCello/history.json
//   ./build/qa/seed_demo /tmp/x     # écrit dans <dossier>/history.json

struct SeededRNG {
    var state: UInt64

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    /// Valeur dans [min, max].
    mutating func value(_ min: Double, _ max: Double) -> Double {
        min + next() * (max - min)
    }

    mutating func int(_ range: Range<Int>) -> Int {
        range.lowerBound + Int(next() * Double(range.count))
    }
}

func gaussian(_ rng: inout SeededRNG) -> Double {
    // Box-Muller
    let u1 = max(rng.next(), 1e-12)
    let u2 = rng.next()
    return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
}

struct DemoSession {
    let record: SessionRecord
    let day: Int
}

func makeDemoRecords() -> [SessionRecord] {
    var rng = SeededRNG(state: 0xC0110_2026)
    let pieces = [
        ("Suite n°1 en sol majeur, BWV 1007", 90.0, 96),
        ("Allegro appassionato, Op.43", 100.0, 120),
        ("Sérénade espagnole, Op.20", 80.0, 72),
        ("Le Cygne (Carnaval des animaux)", 70.0, 64)
    ]

    let today = Calendar.current.startOfDay(for: Date())
    var records: [SessionRecord] = []

    // Une séance la plupart des jours, sur 28 jours, progression globale.
    // Quelques jours sans séance (réalisme) ; les 6 derniers jours sont complets
    // pour afficher une série dans le profil.
    for dayIndex in 1...28 {
        let daysAgo = 28 - dayIndex
        if rng.next() < 0.18, daysAgo > 5 { continue }
        let isPiece = dayIndex % 4 == 0
        let progress = Double(dayIndex) / 28.0 // 0 (début) → 1 (récent)

        // Quelques jours difficiles pour casser la courbe.
        let badDay = (dayIndex == 4 || dayIndex == 17) ? 1.0 : 0.0

        let date = today.addingTimeInterval(
            -Double(daysAgo) * 86_400 + rng.value(16 * 3600, 20 * 3600)
        )
        let duration = rng.value(600, 2700)

        if isPiece {
            let piece = pieces[dayIndex / 4 % pieces.count]
            let total = piece.2
            let matched = Int(Double(total) * rng.value(0.72, 0.97))
            let inTuneRatio = min(0.98, 0.5 + progress * 0.45 - badDay * 0.2 + rng.value(-0.08, 0.08))
            let inTune = Int(Double(matched) * inTuneRatio)
            let meanCents = max(5, 30 - progress * 24 - badDay * 6 + rng.value(-4, 4))
            let rhythm = max(70, 230 - progress * 130 + rng.value(-30, 30))
            let outOfScore = Int(rng.value(0, 4)) - (progress > 0.7 ? 2 : 0)
            let record = SessionRecord(
                id: UUID(),
                date: date,
                mode: "Morceau",
                title: piece.0,
                duration: duration,
                posture: [],
                noteCount: matched,
                inTuneNotes: inTune,
                meanAbsCents: meanCents,
                meanStability: max(4, 16 - progress * 11 + rng.value(-2, 2)),
                soundingSeconds: 0,
                noteCents: [],
                noteStability: [],
                piece: PieceRecord(
                    title: piece.0,
                    matched: matched,
                    total: total,
                    inTune: inTune,
                    meanAbsCents: meanCents,
                    meanAbsRhythmMs: rhythm,
                    outOfScore: max(0, outOfScore),
                    estimatedTempo: piece.1 + rng.value(-8, 8)
                )
            )
            records.append(record)
            continue
        }

        // Séance libre : son + posture.
        let noteCount = Int(rng.value(12, 46))
        let meanCents = max(6, 32 - progress * 26 - badDay * 8 + rng.value(-6, 6))
        var noteCents: [Double] = []
        var noteStability: [Double] = []
        var inTune = 0
        let meanStability = max(4, 18 - progress * 12 + rng.value(-3, 3))
        for _ in 0..<noteCount {
            let cents = meanCents + gaussian(&rng) * 9
            noteCents.append(min(max(cents, -70), 70))
            noteStability.append(min(max(meanStability + gaussian(&rng) * 4, 1), 40))
            if abs(cents) <= 25 { inTune += 1 }
        }

        let postureSeconds = (1 - progress) * (badDay > 0 ? 220 : 140) + rng.value(-15, 15)
        var posture: [PostureRecord] = []
        let rules = [
            ("A1", "Tête en avant"),
            ("A2", "Épaules haussées"),
            ("A3", "Épaules voûtées"),
            ("A4", "Épaule droite plus haute")
        ]
        for (index, rule) in rules.enumerated() {
            // A4 s'améliore plus lentement : axe prioritaire du profil.
            let factor = index == 3 ? 0.75 : 1.0
            let seconds = max(0, postureSeconds * factor * rng.value(0.5, 1.3))
            posture.append(
                PostureRecord(
                    ruleID: rule.0,
                    title: rule.1,
                    seconds: seconds,
                    occurrences: max(0, Int(seconds / 28) + Int(rng.value(0, 3)))
                )
            )
        }

        let pitchFrames = Int(duration * 5)
        let bowFrames = Int(duration * 3)
        let record = SessionRecord(
            id: UUID(),
            date: date,
            mode: "Séance libre",
            title: "Séance libre",
            duration: duration,
            posture: posture,
            noteCount: noteCount,
            inTuneNotes: inTune,
            meanAbsCents: meanCents,
            meanStability: meanStability,
            soundingSeconds: duration * rng.value(0.62, 0.92),
            noteCents: noteCents,
            noteStability: noteStability,
            piece: nil,
            bow: BowRecord(
                frames: bowFrames,
                goodAngle: min(bowFrames, Int(Double(bowFrames) * (0.55 + progress * 0.4) * rng.value(0.92, 1.02))),
                goodZone: min(bowFrames, Int(Double(bowFrames) * (0.6 + progress * 0.35) * rng.value(0.9, 1.04)))
            ),
            meanHNR: 11 + progress * 9 + rng.value(-2, 2),
            meanCentroid: rng.value(900, 1500),
            meanRMSVariation: rng.value(0.2, 0.55),
            postureDetectionRate: rng.value(0.82, 1.0),
            medianFrequency: [98.0, 146.8, 196.0, 220.0][rng.int(0..<4)],
            validPitchFrames: Int(Double(pitchFrames) * rng.value(0.7, 0.98)),
            pitchFrames: pitchFrames,
            articulationCounts: [
                "Détaché": Int(rng.value(8, 24)),
                "Legato": Int(rng.value(6, 18)),
                "Martelé": Int(rng.value(0, 8)),
                "Staccato": Int(rng.value(0, 10)),
                "Spiccato": progress > 0.5 ? Int(rng.value(0, 6)) : 0,
                "Sautillé": progress > 0.7 ? Int(rng.value(0, 5)) : 0
            ],
            meanVibratoRate: progress > 0.4 ? rng.value(4.2, 5.8) : nil,
            meanVibratoExtent: progress > 0.4 ? rng.value(20, 60) : nil
        )
        records.append(record)
    }

    // Tri du plus récent au plus ancien (comme ProgressStore.add).
    return records.sorted { $0.date > $1.date }
}

func run() {
    let arguments = CommandLine.arguments
    let directory: URL
    if arguments.count > 1 {
        directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
    } else {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("OpenCello", isDirectory: true)
    }

    let records = makeDemoRecords()
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("history.json")
        let data = try encoder.encode(records)
        try data.write(to: url)
        print("WROTE:", url.path, "records:", records.count)

        for record in records.prefix(6) {
            let score = SessionScore.compute(for: record)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM HH:mm"
            print(
                "  \(record.mode) | \(formatter.string(from: record.date)) | \(Int(record.duration / 60)) min | score \(score.total) (\(score.tierLabel))"
            )
        }
        print("  …")
        let profile = ProfileSummary.compute(records: records)
        print(
            "PROFILE: sessions \(profile.sessionCount), streak \(profile.currentStreak) j, score moyen \(String(format: "%.0f", profile.averageScore ?? 0)), tendances \(profile.trends.count)"
        )
    } catch {
        print("ERROR:", error)
        exit(1)
    }
}

@main
struct SeedDemo {
    static func main() {
        run()
    }
}
