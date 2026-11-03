import Foundation

// omr_follower_compat.swift — Vérifie que le MusicXML produit par le pipeline
// OMR (docs/18) est accepté par le parseur de l'app (MusicXMLParser.swift)
// et suivi par ScoreFollower.
// Usage : omr_follower_compat <score.musicxml>

@main
struct OMRFollowerCompat {
    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            print("Usage : omr_follower_compat <score.musicxml>")
            exit(1)
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let score = try MusicXMLParser.parse(data: data)
            print("TITLE:", score.title)
            print("COMPOSER:", score.composer ?? "-")
            print("TEMPO:", score.tempo ?? -1)
            for part in score.parts {
                print("PART:", part.name, "notes:", part.notes.count)
            }
            print("TOTAL:", score.parts.reduce(0) { $0 + $1.notes.count }, "note(s)")

            guard let partIndex = score.parts.firstIndex(where: { !$0.notes.isEmpty }) else {
                print("ERROR: aucune note exploitable")
                exit(1)
            }
            let follower = ScoreFollower(score: score, partIndex: partIndex, bpm: score.tempo ?? 100)
            let first = score.parts[partIndex].notes[0]
            let feedback = follower.process(midi: Double(first.midi), onset: 0)
            print("SUIVI:", feedback.matched, feedback.message)
        } catch {
            print("ERROR:", error)
            exit(1)
        }
    }
}
