import Foundation
import CoreGraphics

func makeLineImage(width: Int = 320, height: Int = 180, angleDegrees: Double) -> [UInt8] {
    var gray = [UInt8](repeating: 0, count: width * height)
    let angle = angleDegrees * .pi / 180
    let dx = cos(angle)
    let dy = sin(angle)
    let centerX = Double(width) / 2
    let centerY = Double(height) / 2

    for t in stride(from: -500.0, through: 500.0, by: 0.5) {
        let x = Int(round(centerX + dx * t))
        let y = Int(round(centerY + dy * t))
        for offsetX in -1...1 {
            for offsetY in -1...1 {
                let px = x + offsetX
                let py = y + offsetY
                if px >= 0, px < width, py >= 0, py < height {
                    gray[py * width + px] = 255
                }
            }
        }
    }
    return gray
}

@main
struct BowTest {
    static func main() {
        let width = 320
        let height = 180

        let gray = makeLineImage(width: width, height: height, angleDegrees: 30)
        let lines = LineDetector.detect(gray: gray, width: width, height: height)
        if let first = lines.first {
            let direction = (first.theta + .pi / 2) * 180 / .pi
            let normalized = direction.truncatingRemainder(dividingBy: 180)
            print("DETECT angle:", String(format: "%.1f", normalized), "support:", first.support)
        } else {
            print("DETECT: FAILED")
        }

        let reference = BowReference(
            bridge: CGPoint(x: 0.5, y: 0.8),
            fingerboard: CGPoint(x: 0.5, y: 0.2)
        )
        let size = CGSize(width: width, height: height)

        if let evaluation = BowGeometry.evaluate(
            lines: [HoughLine(theta: .pi / 2, rho: 90, support: 100)],
            reference: reference,
            imageSize: size
        ) {
            print(
                "EVAL horizontal: angle", String(format: "%.1f", evaluation.angleDeviation),
                "contact", String(format: "%.2f", evaluation.contact),
                "angleOK", evaluation.angleOK,
                "zoneOK", evaluation.zoneOK
            )
        } else {
            print("EVAL horizontal: FAILED")
        }

        let angle = 7.0 * .pi / 180
        let normalTheta = .pi / 2 + angle
        let midpoint = CGPoint(x: 160, y: 90)
        let rho = midpoint.x * cos(normalTheta) + midpoint.y * sin(normalTheta)
        if let evaluation = BowGeometry.evaluate(
            lines: [HoughLine(theta: normalTheta, rho: rho, support: 100)],
            reference: reference,
            imageSize: size
        ) {
            print("EVAL tilt7: angle", String(format: "%.1f", evaluation.angleDeviation))
        }

        if let evaluation = BowGeometry.evaluate(
            lines: [HoughLine(theta: .pi / 2, rho: 63, support: 100)],
            reference: reference,
            imageSize: size
        ) {
            print("EVAL contact75:", String(format: "%.2f", evaluation.contact), "zoneOK", evaluation.zoneOK)
        }

        if let evaluation = BowGeometry.evaluate(
            lines: [HoughLine(theta: .pi / 2, rho: 138.6, support: 100)],
            reference: reference,
            imageSize: size
        ) {
            print("EVAL contact05:", String(format: "%.2f", evaluation.contact), "zoneOK", evaluation.zoneOK)
        }

        let vectorizer = BowVectorizer()
        func vector(offset: CGFloat, contact: Double, time: TimeInterval) -> BowVector {
            let evaluation = BowEvaluation(
                angleDeviation: 2,
                contact: contact,
                contactPoint: CGPoint(x: 0.5, y: 0.5),
                angleOK: true,
                zoneOK: true,
                line: BowLine(
                    start: CGPoint(x: 0.4 + offset, y: 0.5),
                    end: CGPoint(x: 0.6 + offset, y: 0.5)
                ),
                confidence: 0.9
            )
            return vectorizer.update(evaluation, timestamp: time)
        }
        _ = vector(offset: 0.00, contact: 0.2, time: 1.0)
        _ = vector(offset: 0.01, contact: 0.2, time: 1.1)
        let moving = vector(offset: 0.02, contact: 0.2, time: 1.2)
        print("VECTOR:", moving.zone.rawValue, moving.motion.rawValue, String(format: "speed %.3f", moving.speed))
        let bridge = vector(offset: 0.03, contact: 0.8, time: 1.3)
        print("VECTOR zone chevalet:", bridge.zone.rawValue)
    }
}
