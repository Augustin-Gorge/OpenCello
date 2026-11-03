import Foundation

@main
struct MusicXMLFollowerTest {
    static func main() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: "tools/qa/sample.musicxml"))
    let score = try MusicXMLParser.parse(data: data)
    print("TITLE:", score.title)
    print("COMPOSER:", score.composer ?? "-")
    print("TEMPO:", score.tempo ?? -1)
    print("PARTS:", score.parts.map { "\($0.name):\($0.notes.count)" }.joined(separator: ", "))
    print("DEFAULT PART:", score.defaultPartIndex)

    for note in score.parts[0].notes {
        print("NOTE midi=\(note.midi) onset=\(note.onsetBeats) dur=\(note.durationBeats) measure=\(note.measureIndex)")
    }

    let follower = ScoreFollower(score: score, partIndex: 0, bpm: 120)
    let onsets: [Double] = [0, 0.5, 1.5, 2.0, 3.0]
    let midis: [Double] = [36, 38, 40, 42, 43]
    for index in 0..<midis.count {
        let feedback = follower.process(midi: midis[index], onset: onsets[index])
        print("STEP \(index): matched=\(feedback.matched) exp=\(feedback.expectedName) cents=\(feedback.cents ?? 999) rhythm=\(feedback.rhythmMs ?? 999) msg=\(feedback.message)")
    }

    let miss = follower.process(midi: 61, onset: 3.5)
    print("MISS:", miss.matched, miss.message)

    print("STATS matched=\(follower.stats.matched)/\(follower.stats.totalNotes) inTune=\(follower.stats.inTune) out=\(follower.stats.outOfScore) meanCents=\(String(format: "%.1f", follower.stats.meanAbsCents)) meanRhythm=\(String(format: "%.0f", follower.stats.meanAbsRhythmMs)) tempo=\(follower.stats.estimatedTempo ?? -1)")
        } catch {
            print("ERROR:", error)
            exit(1)
        }
    }
}
