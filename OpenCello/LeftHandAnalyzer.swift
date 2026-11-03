import Foundation
import CoreGraphics

/// Points de la main suivis par Vision Hands, dans un type indépendant de Vision
/// pour que les analyseurs et les tests CLI restent compilables sans framework.
enum HandJoint: String, CaseIterable {
    case wrist
    case thumbTip
    case thumbIP
    case thumbMP
    case thumbCMC
    case indexTip
    case indexPIP
    case indexMCP
    case middleTip
    case middlePIP
    case middleMCP
    case ringTip
    case ringPIP
    case ringMCP
    case littleTip
    case littlePIP
    case littleMCP
}

struct HandPoint {
    let joint: HandJoint
    let point: CGPoint
    let confidence: Float
}

struct HandFrame {
    let points: [HandPoint]
    let confidence: Float
    let timestamp: TimeInterval

    func point(_ joint: HandJoint) -> CGPoint? {
        points.first { $0.joint == joint }?.point
    }

    func confidence(_ joint: HandJoint) -> Float {
        points.first { $0.joint == joint }?.confidence ?? 0
    }
}

/// Références corporelles utiles à la main gauche (issues de Vision Body).
struct BodyReference {
    var leftShoulder: CGPoint?
    var leftElbow: CGPoint?
    var leftWrist: CGPoint?
    var shoulderWidth: Double?

    var isValid: Bool {
        leftShoulder != nil && leftElbow != nil && leftWrist != nil
    }
}

/// Métriques main gauche d'une frame.
/// P11 = angle main/avant-bras, P12 = pouce (hypothèse), P13 = souplesse,
/// P14 = position estimée sur la touche.
struct LeftHandMetrics {
    var valid = false
    var handAngleDegrees: Double?
    var signedHandAngleDegrees: Double?
    var fingerCurl: Double?
    var fingerSpeed: Double?
    var fingerSpeedP90: Double?
    var presserFinger: Int?
    var presserConfidence: Double = 0
    var thumbHypothesis = false
    var thumbConfidence: Double = 0
    var positionHint: Int?
    var positionHintConfidence: Double = 0
    var elbowMobility: Double = 0
    var flags: [String: Bool] = [:]
    var timestamp: TimeInterval = 0
}

/// Analyse la main gauche à partir des 21 points Vision Hands et des repères
/// du corps. Toutes les sorties sont des estimations : A18 (pouce) reste une
/// hypothèse explicite, la position a une résolution d'environ ±1 position.
final class LeftHandAnalyzer {
    var thresholds = HandThresholds.forProfile(.intermediate)

    private var previousTips: [HandJoint: CGPoint] = [:]
    private var previousTime: TimeInterval?
    private var speedHistory: [Double] = []
    private var elbowHistory: [(time: TimeInterval, point: CGPoint)] = []
    private var reachMin = 0.75
    private var reachMax = 1.25

    private let fingerTips: [(joint: HandJoint, finger: Int)] = [
        (.indexTip, 1),
        (.middleTip, 2),
        (.ringTip, 3),
        (.littleTip, 4)
    ]

    func reset() {
        previousTips = [:]
        previousTime = nil
        speedHistory = []
        elbowHistory = []
        reachMin = 0.75
        reachMax = 1.25
    }

    /// Choisit la main la plus probablement gauche : la plus proche du poignet
    /// gauche du corps, sinon la plus confiante.
    func selectHand(_ hands: [HandFrame], body: BodyReference) -> HandFrame? {
        guard !hands.isEmpty else { return nil }
        if let leftWrist = body.leftWrist {
            return hands.min { lhs, rhs in
                distance(lhs.point(.wrist), leftWrist) < distance(rhs.point(.wrist), leftWrist)
            }
        }
        return hands.max { $0.confidence < $1.confidence }
    }

    func analyze(hands: [HandFrame], body: BodyReference, timestamp: TimeInterval) -> LeftHandMetrics? {
        updateElbow(body.leftElbow, timestamp: timestamp)
        guard let hand = selectHand(hands, body: body),
              let wrist = hand.point(.wrist),
              let middleTip = hand.point(.middleTip) else {
            return nil
        }

        var metrics = LeftHandMetrics(timestamp: timestamp)
        metrics.elbowMobility = elbowMobility()
        let handSpan = max(0.02, distance(wrist, hand.point(.middleMCP) ?? middleTip))

        if let elbow = body.leftElbow, let bodyWrist = body.leftWrist {
            let forearm = CGVector(dx: bodyWrist.x - elbow.x, dy: bodyWrist.y - elbow.y)
            let axis = CGVector(dx: middleTip.x - wrist.x, dy: middleTip.y - wrist.y)
            if let angle = signedAngle(forearm, axis), abs(angle) <= 75 {
                // Au-delà de ~75°, l'axe main/avant-bras est presque toujours
                // une erreur de landmarks (occlusion, main de l'autre côté) :
                // on préfère ne pas mesurer plutôt que produire un faux A17.
                metrics.handAngleDegrees = abs(angle)
                metrics.signedHandAngleDegrees = angle
                metrics.valid = true
            }
        }

        metrics.fingerCurl = fingerCurl(hand)
        metrics.fingerSpeed = fingerSpeed(hand, handSpan: handSpan, timestamp: timestamp)
        if let speed = metrics.fingerSpeed {
            speedHistory.append(speed)
            if speedHistory.count > 90 { speedHistory.removeFirst(speedHistory.count - 90) }
        }
        metrics.fingerSpeedP90 = percentile(speedHistory, 0.90)

        let position = positionHint(body: body, handWrist: wrist)
        metrics.positionHint = position.position
        metrics.positionHintConfidence = position.confidence

        let presser = presserFinger(hand, handSpan: handSpan, positionHint: position.position)
        metrics.presserFinger = presser.finger
        metrics.presserConfidence = presser.confidence

        let thumb = thumbHypothesis(hand, handSpan: handSpan, metrics: metrics)
        metrics.thumbHypothesis = thumb.flagged
        metrics.thumbConfidence = thumb.confidence

        metrics.flags["A17"] = metrics.valid && (metrics.handAngleDegrees ?? 0) > thresholds.handAngleLimit
        metrics.flags["A18"] = metrics.valid && metrics.thumbHypothesis
        metrics.flags["A19"] = metrics.valid && (metrics.fingerSpeedP90 ?? 0) > thresholds.fingerSpeedLimit

        return metrics
    }

    /// Mobilité du coude sur les dernières 0,6 s, normalisée par la largeur
    /// d'épaules. Sert à A20 pendant un déplacement.
    func elbowMobility() -> Double {
        guard elbowHistory.count >= 2 else { return 0 }
        var path = 0.0
        for index in 1..<elbowHistory.count {
            path += distance(elbowHistory[index - 1].point, elbowHistory[index].point)
        }
        return path
    }

    // MARK: - Calculs

    private func updateElbow(_ elbow: CGPoint?, timestamp: TimeInterval) {
        guard let elbow else { return }
        elbowHistory.append((timestamp, elbow))
        elbowHistory.removeAll { timestamp - $0.time > 0.6 }
    }

    private func fingerCurl(_ hand: HandFrame) -> Double? {
        let fingers: [(HandJoint, HandJoint, HandJoint)] = [
            (.indexMCP, .indexPIP, .indexTip),
            (.middleMCP, .middlePIP, .middleTip),
            (.ringMCP, .ringPIP, .ringTip),
            (.littleMCP, .littlePIP, .littleTip)
        ]
        var values: [Double] = []
        for (mcp, pip, tip) in fingers {
            guard let a = hand.point(mcp), let b = hand.point(pip), let c = hand.point(tip) else { continue }
            let v1 = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            guard let angle = unsignedAngle(v1, v2) else { continue }
            // 180° = doigt tendu (0), 60° = doigt très enroulé (1).
            values.append(max(0, min(1, (180 - angle) / 120)))
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func fingerSpeed(_ hand: HandFrame, handSpan: Double, timestamp: TimeInterval) -> Double? {
        guard let previousTime else {
            storeTips(hand)
            self.previousTime = timestamp
            return nil
        }
        let dt = timestamp - previousTime
        guard dt > 0.01, dt < 0.5 else {
            storeTips(hand)
            self.previousTime = timestamp
            return nil
        }

        var speeds: [Double] = []
        for (joint, _) in fingerTips {
            guard let current = hand.point(joint), let previous = previousTips[joint] else { continue }
            speeds.append(distance(current, previous) / dt / handSpan)
        }
        storeTips(hand)
        self.previousTime = timestamp
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    private func storeTips(_ hand: HandFrame) {
        for (joint, _) in fingerTips {
            if let point = hand.point(joint) {
                previousTips[joint] = point
            }
        }
    }

    /// Le doigt presseur est le bout le plus bas dans l'image (le plus proche
    /// du plan des cordes), avec une confiance liée à l'écart avec le suivant.
    private func presserFinger(
        _ hand: HandFrame,
        handSpan: Double,
        positionHint: Int?
    ) -> (finger: Int?, confidence: Double) {
        let candidates: [(finger: Int, point: CGPoint)] = fingerTips.compactMap { item in
            guard let point = hand.point(item.joint) else { return nil }
            return (item.finger, point)
        }
        guard candidates.count >= 2 else {
            return (candidates.first?.finger, candidates.isEmpty ? 0 : 0.25)
        }
        // Le doigt qui appuie est celui qui s'étend le plus loin vers la
        // touche : dans une vue 3/4, c'est le point le plus haut de la main,
        // pas le plus bas (le 4e doigt est court et tombait toujours en bas).
        let sorted = candidates.sorted { $0.point.y > $1.point.y }
        if let hint = positionHint, hint >= 5,
           let thumb = hand.point(.thumbTip),
           let lowest = sorted.last?.point,
           thumb.y < lowest.y - handSpan * 0.08 {
            // Pouce en position haute : il est posé sur la corde, sous les
            // doigts ; on ne l'accepte que si la main est déjà haut.
            let gap = lowest.y - thumb.y
            let confidence = min(0.85, max(0.30, gap / max(0.01, handSpan * 0.25)))
            return (5, confidence)
        }
        let gap = abs(sorted[0].point.y - sorted[1].point.y)
        let confidence = min(0.85, max(0.20, gap / max(0.01, handSpan * 0.35)))
        return (sorted[0].finger, confidence)
    }

    /// Pouce : hypothèse fondée sur l'écart pouce/index et sur une main
    /// cassée avec des doigts peu mobiles. Jamais présenté comme une certitude.
    private func thumbHypothesis(_ hand: HandFrame, handSpan: Double, metrics: LeftHandMetrics) -> (flagged: Bool, confidence: Double) {
        guard let thumb = hand.point(.thumbTip), let indexMCP = hand.point(.indexMCP) else {
            return (false, 0)
        }
        let ratio = distance(thumb, indexMCP) / handSpan
        let farThumb = ratio > 0.95
        let pinchedThumb = ratio < 0.30
        let stiff = (metrics.fingerSpeedP90 ?? 0) < 0.35
        let broken = (metrics.handAngleDegrees ?? 0) > thresholds.handAngleLimit
        let highPosition = (metrics.positionHint ?? 0) >= 6
        let flagged = highPosition && (farThumb || pinchedThumb || (broken && stiff))
        let confidence: Double
        if farThumb || pinchedThumb {
            confidence = min(0.65, 0.35 + abs(ratio - 0.6) * 0.4)
        } else if broken && stiff {
            confidence = 0.35
        } else {
            confidence = 0
        }
        return (flagged, confidence)
    }

    /// Position estimée à partir de l'allongement du bras (distance épaule-poignet
    /// normalisée). C'est un indice faible : le son et la continuité priment.
    private func positionHint(body: BodyReference, handWrist: CGPoint) -> (position: Int?, confidence: Double) {
        guard let shoulder = body.leftShoulder,
              let width = body.shoulderWidth, width > 0.01 else {
            return (nil, 0)
        }
        let wrist = body.leftWrist ?? handWrist
        let reach = distance(shoulder, wrist) / width
        guard reach > 0.1 else { return (nil, 0) }

        reachMin = min(reachMin, reach)
        reachMax = max(reachMax, reach)
        if reachMax - reachMin < 0.18 {
            reachMax = reachMin + 0.18
        }
        let normalized = max(0, min(1, (reach - reachMin) / (reachMax - reachMin)))
        let position = max(1, min(7, Int((1 + normalized * 6).rounded())))
        let confidence = reachMax - reachMin >= 0.25 ? 0.35 : 0.22
        return (position, confidence)
    }

    private func signedAngle(_ a: CGVector, _ b: CGVector) -> Double? {
        let lengthA = hypot(a.dx, a.dy)
        let lengthB = hypot(b.dx, b.dy)
        guard lengthA > 0.0001, lengthB > 0.0001 else { return nil }
        let cosine = max(-1, min(1, (a.dx * b.dx + a.dy * b.dy) / (lengthA * lengthB)))
        let angle = acos(cosine) * 180 / .pi
        let cross = a.dx * b.dy - a.dy * b.dx
        return cross < 0 ? -angle : angle
    }

    private func unsignedAngle(_ a: CGVector, _ b: CGVector) -> Double? {
        signedAngle(a, b).map(abs)
    }

    private func distance(_ a: CGPoint?, _ b: CGPoint?) -> Double {
        guard let a, let b else { return 0 }
        return hypot(a.x - b.x, a.y - b.y)
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * p)))
        return sorted[index]
    }
}
