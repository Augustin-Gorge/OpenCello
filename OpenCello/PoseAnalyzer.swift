import Foundation
import Vision
import CoreMedia
import CoreGraphics

struct Landmark: Identifiable {
    let id = UUID()
    let joint: VNHumanBodyPoseObservation.JointName
    let point: CGPoint
    let confidence: Float
}

struct PoseMetrics {
    var valid = false
    var shoulderWidth: Double = 0
    var neckGap: Double = 0
    var headForwardProxy: Double?
    var headTiltDegrees: Double?
    var shoulderAsymmetry: Double = 0
}

struct PoseFrame {
    let landmarks: [Landmark]
    let metrics: PoseMetrics
    /// Mains détectées par Vision Hands (0-2). La main gauche est choisie par
    /// `LeftHandAnalyzer` à partir du poignet gauche du corps.
    var hands: [HandFrame] = []
    let timestamp: TimeInterval
}

/// Encapsule Vision (VNDetectHumanBodyPoseRequest) et calcule des métriques
/// de posture invariantes d'échelle (adaptées du modèle ErgoGuard).
final class PoseAnalyzer {
    private let request = VNDetectHumanBodyPoseRequest()
    private let handAnalyzer = HandPoseAnalyzer()

    func analyze(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> PoseFrame? {
        let hands = handAnalyzer.analyze(pixelBuffer: pixelBuffer, timestamp: timestamp)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return hands.isEmpty ? nil : PoseFrame(landmarks: [], metrics: PoseMetrics(), hands: hands, timestamp: timestamp)
        }
        guard let observation = request.results?.first else {
            return hands.isEmpty ? nil : PoseFrame(landmarks: [], metrics: PoseMetrics(), hands: hands, timestamp: timestamp)
        }
        let landmarks = Self.landmarks(from: observation)
        let metrics = Self.metrics(from: landmarks)
        return PoseFrame(landmarks: landmarks, metrics: metrics, hands: hands, timestamp: timestamp)
    }

    private static func landmarks(from observation: VNHumanBodyPoseObservation) -> [Landmark] {
        let joints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftEar, .rightEar,
            .leftHip, .rightHip
        ]
        var result: [Landmark] = []
        for joint in joints {
            guard let point = try? observation.recognizedPoint(joint), point.confidence > 0.25 else { continue }
            result.append(
                Landmark(
                    joint: joint,
                    point: CGPoint(x: point.location.x, y: point.location.y),
                    confidence: point.confidence
                )
            )
        }
        return result
    }

    private static func metrics(from landmarks: [Landmark]) -> PoseMetrics {
        var lookup: [VNHumanBodyPoseObservation.JointName: Landmark] = [:]
        for landmark in landmarks {
            lookup[landmark.joint] = landmark
        }

        var metrics = PoseMetrics()
        guard let leftShoulder = lookup[.leftShoulder],
              let rightShoulder = lookup[.rightShoulder] else {
            return metrics
        }

        let width = hypot(
            rightShoulder.point.x - leftShoulder.point.x,
            rightShoulder.point.y - leftShoulder.point.y
        )
        guard width > 0.01 else { return metrics }

        metrics.shoulderWidth = Double(width)
        metrics.shoulderAsymmetry = Double(abs(rightShoulder.point.y - leftShoulder.point.y) / width)

        let shoulderMid = CGPoint(
            x: (leftShoulder.point.x + rightShoulder.point.x) / 2,
            y: (leftShoulder.point.y + rightShoulder.point.y) / 2
        )

        if let neck = lookup[.neck] {
            metrics.neckGap = Double((neck.point.y - shoulderMid.y) / width)
            if let nose = lookup[.nose] {
                metrics.headForwardProxy = Double((nose.point.x - neck.point.x) / width)
            }
            if let ear = lookup[.rightEar] ?? lookup[.leftEar] {
                let dx = Double(ear.point.x - neck.point.x)
                let dy = Double(ear.point.y - neck.point.y)
                if dy != 0 {
                    metrics.headTiltDegrees = abs(atan2(dx, dy) * 180 / .pi)
                }
            }
            metrics.valid = true
        } else if let nose = lookup[.nose] {
            metrics.neckGap = Double((nose.point.y - shoulderMid.y) / width)
            metrics.valid = true
        }

        return metrics
    }
}
