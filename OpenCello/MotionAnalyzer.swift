import Foundation
import CoreGraphics

struct MotionMetrics {
    let jerk: Double
    let stillness: Double
    let samples: Int
}

/// Suit la fluidité du bras droit et la mobilisation tête/buste.
/// Indicateurs indicatifs, à calibrer sur des enregistrements réels.
final class MotionAnalyzer {
    private struct Sample {
        let time: TimeInterval
        let wrist: CGPoint
        let head: CGPoint
        let shoulder: CGPoint
    }

    private var samples: [Sample] = []
    private let window: TimeInterval = 12

    func add(wrist: CGPoint, head: CGPoint, shoulder: CGPoint, timestamp: TimeInterval) {
        samples.append(Sample(time: timestamp, wrist: wrist, head: head, shoulder: shoulder))
        if let first = samples.first, timestamp - first.time > window {
            samples.removeAll { timestamp - $0.time > window }
        }
    }

    func reset() {
        samples.removeAll()
    }

    func metrics() -> MotionMetrics? {
        guard samples.count >= 6 else { return nil }

        var velocities: [(time: TimeInterval, value: CGVector)] = []
        for index in 1..<samples.count {
            let dt = samples[index].time - samples[index - 1].time
            guard dt > 0.001 else { continue }
            let dx = samples[index].wrist.x - samples[index - 1].wrist.x
            let dy = samples[index].wrist.y - samples[index - 1].wrist.y
            velocities.append((samples[index].time, CGVector(dx: dx / dt, dy: dy / dt)))
        }
        guard velocities.count >= 4 else { return nil }

        var accelerations: [(time: TimeInterval, value: CGVector)] = []
        for index in 1..<velocities.count {
            let dt = velocities[index].time - velocities[index - 1].time
            guard dt > 0.001 else { continue }
            let dx = velocities[index].value.dx - velocities[index - 1].value.dx
            let dy = velocities[index].value.dy - velocities[index - 1].value.dy
            accelerations.append((velocities[index].time, CGVector(dx: dx / dt, dy: dy / dt)))
        }
        guard accelerations.count >= 2 else { return nil }

        var jerkSum = 0.0
        for index in 1..<accelerations.count {
            let dt = accelerations[index].time - accelerations[index - 1].time
            guard dt > 0.001 else { continue }
            let dx = (accelerations[index].value.dx - accelerations[index - 1].value.dx) / dt
            let dy = (accelerations[index].value.dy - accelerations[index - 1].value.dy) / dt
            jerkSum += hypot(dx, dy)
        }
        let jerk = jerkSum / Double(accelerations.count - 1)

        let headXs = samples.map { $0.head.x }
        let headYs = samples.map { $0.head.y }
        let shoulderXs = samples.map { $0.shoulder.x }
        let shoulderYs = samples.map { $0.shoulder.y }
        let stillness = (
            variance(headXs) + variance(headYs) + variance(shoulderXs) + variance(shoulderYs)
        ).squareRoot()

        return MotionMetrics(jerk: jerk, stillness: stillness, samples: samples.count)
    }

    private func variance(_ values: [CGFloat]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / CGFloat(values.count)
        return Double(values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / CGFloat(values.count))
    }
}
