import Foundation
import CoreGraphics

enum AnalysisMode: String, CaseIterable {
    case posture = "Posture (face)"
    case bow = "Archet (profil)"
}

/// Repère calibré par l'utilisateur : chevalet et bout de la touche.
/// Coordonnées normalisées dans l'image (origine en haut à gauche, y vers le bas).
struct BowReference {
    let bridge: CGPoint
    let fingerboard: CGPoint
}

struct BowLine: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
}

struct BowEvaluation {
    let angleDeviation: Double
    let contact: Double
    let angleOK: Bool
    let zoneOK: Bool
    let line: BowLine
    let confidence: Double
}

enum BowGeometry {
    /// Évalue l'angle et la zone de contact de l'archet.
    /// - `angleTolerance` : écart maximal à la perpendicularité, en degrés.
    static func evaluate(
        lines: [HoughLine],
        reference: BowReference,
        imageSize: CGSize,
        angleTolerance: Double = 10
    ) -> BowEvaluation? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let bridge = CGPoint(
            x: reference.bridge.x * imageSize.width,
            y: reference.bridge.y * imageSize.height
        )
        let fingerboard = CGPoint(
            x: reference.fingerboard.x * imageSize.width,
            y: reference.fingerboard.y * imageSize.height
        )

        let axis = CGVector(dx: fingerboard.x - bridge.x, dy: fingerboard.y - bridge.y)
        let axisLength = hypot(axis.dx, axis.dy)
        guard axisLength > 8 else { return nil }

        let midpoint = CGPoint(
            x: (bridge.x + fingerboard.x) / 2,
            y: (bridge.y + fingerboard.y) / 2
        )

        var best: (line: HoughLine, deviation: Double, contact: Double, score: Double)?

        for line in lines {
            let normal = CGVector(dx: cos(line.theta), dy: sin(line.theta))
            let direction = CGVector(dx: -sin(line.theta), dy: cos(line.theta))
            let dot = abs(direction.dx * axis.dx + direction.dy * axis.dy) / axisLength
            let angleBetween = acos(min(1, max(0, dot))) * 180 / .pi
            let deviation = abs(90 - angleBetween)
            guard deviation < 40 else { continue }

            let axisDotNormal = axis.dx * normal.dx + axis.dy * normal.dy
            guard abs(axisDotNormal) > 1e-6 else { continue }
            let contact = ((line.rho - (bridge.x * normal.dx + bridge.y * normal.dy)) / axisDotNormal)
            guard contact > -0.3, contact < 1.3 else { continue }

            let midpointDistance = abs(
                midpoint.x * normal.dx + midpoint.y * normal.dy - line.rho
            )
            let score = deviation + midpointDistance * 0.05 - Double(line.support) * 0.005
            if best == nil || score < (best?.score ?? .greatestFiniteMagnitude) {
                best = (line, deviation, contact, score)
            }
        }

        guard let best,
              let segment = LineDetector.segment(
                for: best.line,
                width: imageSize.width,
                height: imageSize.height
              ) else {
            return nil
        }

        let normalizedStart = CGPoint(
            x: segment.0.x / imageSize.width,
            y: segment.0.y / imageSize.height
        )
        let normalizedEnd = CGPoint(
            x: segment.1.x / imageSize.width,
            y: segment.1.y / imageSize.height
        )

        let angleOK = best.deviation <= angleTolerance
        let zoneOK = best.contact >= 0.1 && best.contact <= 0.9
        let confidence = min(1, max(0, 1 - best.deviation / 45))

        return BowEvaluation(
            angleDeviation: best.deviation,
            contact: best.contact,
            angleOK: angleOK,
            zoneOK: zoneOK,
            line: BowLine(start: normalizedStart, end: normalizedEnd),
            confidence: confidence
        )
    }
}
