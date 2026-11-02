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
    }
}
