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
    let contactPoint: CGPoint
    let angleOK: Bool
    let zoneOK: Bool
    let line: BowLine
    let confidence: Double
}

enum BowZone: String {
    case fingerboard = "sur la touche"
    case middle = "au milieu"
    case bridge = "près du chevalet"

    var colorName: String {
        switch self {
        case .fingerboard: return "orange"
        case .middle: return "green"
        case .bridge: return "blue"
        }
    }
}

enum BowMotion: String {
    case forward = "sens aller"
    case backward = "sens retour"
    case still = "immobile"
}

/// Vecteur d'archet d'une frame : direction, angle, contact et vitesse.
struct BowVector {
    let start: CGPoint
    let end: CGPoint
    let contactPoint: CGPoint
    let angleDeviation: Double
    let contact: Double
    let zone: BowZone
    let motion: BowMotion
    let speed: Double
    let confidence: Double
}

/// Suit le vecteur de l'archet entre deux frames pour estimer le sens du coup
/// (aller/retour), la vitesse et les changements de direction. Le profil est
/// une vue 2D : on ne prétend pas distinguer poussé/tiré sans repère du talon.
final class BowVectorizer {
    private var previous: (midpoint: CGPoint, direction: CGVector, time: TimeInterval, speed: Double)?
    private var committedMotion: BowMotion = .still
    private var pendingMotion: BowMotion = .still
    private var pendingCount = 0
    private(set) var directionChanges = 0

    func reset() {
        previous = nil
        committedMotion = .still
        pendingMotion = .still
        pendingCount = 0
        directionChanges = 0
    }

    func update(_ evaluation: BowEvaluation, timestamp: TimeInterval) -> BowVector {
        let dx = evaluation.line.end.x - evaluation.line.start.x
        let dy = evaluation.line.end.y - evaluation.line.start.y
        let length = max(0.0001, hypot(dx, dy))
        let direction = CGVector(dx: dx / length, dy: dy / length)
        let midpoint = CGPoint(
            x: (evaluation.line.start.x + evaluation.line.end.x) / 2,
            y: (evaluation.line.start.y + evaluation.line.end.y) / 2
        )

        var motion: BowMotion = .still
        var speed = 0.0
        if let previous, timestamp > previous.time {
            let dt = timestamp - previous.time
            if dt > 0.01, dt < 0.6 {
                let move = CGVector(
                    dx: midpoint.x - previous.midpoint.x,
                    dy: midpoint.y - previous.midpoint.y
                )
                speed = hypot(move.dx, move.dy) / dt
                let smoothed = 0.7 * previous.speed + 0.3 * speed
                speed = smoothed
                if speed > 0.02 {
                    let projection = move.dx * previous.direction.dx + move.dy * previous.direction.dy
                    let candidate: BowMotion = projection >= 0 ? .forward : .backward
                    if candidate == pendingMotion {
                        pendingCount += 1
                    } else {
                        pendingMotion = candidate
                        pendingCount = 1
                    }
                    if pendingCount >= 2 {
                        if committedMotion != .still, candidate != committedMotion {
                            directionChanges += 1
                        }
                        committedMotion = candidate
                        motion = candidate
                    } else {
                        motion = committedMotion
                    }
                } else {
                    pendingMotion = .still
                    pendingCount = 0
                    motion = .still
                }
            }
        }
        previous = (midpoint, direction, timestamp, speed)

        let zone: BowZone
        if evaluation.contact < 0.33 {
            zone = .fingerboard
        } else if evaluation.contact > 0.67 {
            zone = .bridge
        } else {
            zone = .middle
        }

        return BowVector(
            start: evaluation.line.start,
            end: evaluation.line.end,
            contactPoint: evaluation.contactPoint,
            angleDeviation: evaluation.angleDeviation,
            contact: evaluation.contact,
            zone: zone,
            motion: motion,
            speed: speed,
            confidence: evaluation.confidence
        )
    }
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

        let clampedContact = max(0, min(1, best.contact))
        let contactPoint = CGPoint(
            x: bridge.x + (fingerboard.x - bridge.x) * clampedContact,
            y: bridge.y + (fingerboard.y - bridge.y) * clampedContact
        )

        return BowEvaluation(
            angleDeviation: best.deviation,
            contact: best.contact,
            contactPoint: CGPoint(
                x: contactPoint.x / imageSize.width,
                y: contactPoint.y / imageSize.height
            ),
            angleOK: angleOK,
            zoneOK: zoneOK,
            line: BowLine(start: normalizedStart, end: normalizedEnd),
            confidence: confidence
        )
    }
}
