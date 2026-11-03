import Foundation
import CoreGraphics

@main
struct Phase5Test {
    static func main() {
        var midis: [Double] = []
        var times: [TimeInterval] = []
        for index in 0..<120 {
            let time = Double(index) / 100
            times.append(time)
            midis.append(60 + 0.3 * sin(2 * Double.pi * 5 * time))
        }
        if let vibrato = VibratoAnalyzer.estimate(midis: midis, timestamps: times) {
            print(
                "VIBRATO rate:", String(format: "%.2f", vibrato.rate),
                "extent:", String(format: "%.1f", vibrato.extent),
                "confidence:", String(format: "%.2f", vibrato.confidence)
            )
        } else {
            print("VIBRATO: FAILED")
        }

        let constant = Array(repeating: 60.0, count: 120)
        print("VIBRATO constant nil:", VibratoAnalyzer.estimate(midis: constant, timestamps: times) == nil)

        let cases: [(String, ArticulationFeatures, Articulation)] = [
            ("legato", ArticulationFeatures(duration: 1.0, attackTime: 0.10, tailRatio: 0.90, rmsVariation: 0.20, gapBefore: 0.02, pitchChange: 0, notesPerSecond: 0.8), .legato),
            ("detache", ArticulationFeatures(duration: 0.60, attackTime: 0.05, tailRatio: 0.80, rmsVariation: 0.20, gapBefore: 0.08, pitchChange: 0, notesPerSecond: 1.0), .detache),
            ("martele", ArticulationFeatures(duration: 0.40, attackTime: 0.02, tailRatio: 0.50, rmsVariation: 0.30, gapBefore: 0.06, pitchChange: 0, notesPerSecond: 1.5), .martele),
            ("staccato", ArticulationFeatures(duration: 0.15, attackTime: 0.02, tailRatio: 0.30, rmsVariation: 0.40, gapBefore: 0.05, pitchChange: 0, notesPerSecond: 2.0), .staccato),
            ("spiccato", ArticulationFeatures(duration: 0.30, attackTime: 0.05, tailRatio: 0.30, rmsVariation: 0.40, gapBefore: 0.05, pitchChange: 0, notesPerSecond: 3.0), .spiccato),
            ("sautille", ArticulationFeatures(duration: 0.12, attackTime: 0.02, tailRatio: 0.40, rmsVariation: 0.50, gapBefore: 0.02, pitchChange: 0, notesPerSecond: 8.0), .sautille),
            ("bariolage", ArticulationFeatures(duration: 0.25, attackTime: 0.03, tailRatio: 0.50, rmsVariation: 0.30, gapBefore: 0.03, pitchChange: 3, notesPerSecond: 4.0), .bariolage),
            ("pizzicato", ArticulationFeatures(duration: 0.80, attackTime: 0.01, tailRatio: 0.20, rmsVariation: 0.60, gapBefore: 0.10, pitchChange: 0, notesPerSecond: 1.0), .pizzicato)
        ]

        for (name, features, expected) in cases {
            let result = ArticulationClassifier.classify(features)
            print("ARTICULATION", name, "→", result.rawValue, result == expected ? "OK" : "MISMATCH")
        }

        let smooth = MotionAnalyzer()
        let jitter = MotionAnalyzer()
        for index in 0..<60 {
            let time = Double(index) / 15
            let smoothPoint = CGPoint(x: 0.5 + 0.05 * sin(time), y: 0.5)
            smooth.add(
                wrist: smoothPoint,
                head: CGPoint(x: 0.5, y: 0.3),
                shoulder: CGPoint(x: 0.4, y: 0.4),
                timestamp: time
            )
            let jitterPoint = CGPoint(
                x: 0.5 + (index % 2 == 0 ? 0.03 : -0.03),
                y: 0.5
            )
            jitter.add(
                wrist: jitterPoint,
                head: CGPoint(x: 0.5, y: 0.3),
                shoulder: CGPoint(x: 0.4, y: 0.4),
                timestamp: time
            )
        }

        if let smoothMetrics = smooth.metrics(), let jitterMetrics = jitter.metrics() {
            print(
                "MOTION smooth jerk:", String(format: "%.2f", smoothMetrics.jerk),
                "jitter jerk:", String(format: "%.2f", jitterMetrics.jerk),
                "jitter>smooth:", jitterMetrics.jerk > smoothMetrics.jerk
            )
        } else {
            print("MOTION: FAILED")
        }
    }
}
