import Foundation
import Vision
import CoreMedia
import CoreGraphics

/// Encapsule Vision Hands (21 points par main, 2 mains maximum) et convertit
/// les observations en `HandFrame`, type indépendant de Vision.
final class HandPoseAnalyzer {
    private let request = VNDetectHumanHandPoseRequest()

    init() {
        request.maximumHandCount = 2
    }

    func analyze(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> [HandFrame] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            frame(from: observation, timestamp: timestamp)
        }
    }

    private func frame(from observation: VNHumanHandPoseObservation, timestamp: TimeInterval) -> HandFrame? {
        var points: [HandPoint] = []
        for (visionJoint, joint) in Self.jointMap {
            guard let recognized = try? observation.recognizedPoint(visionJoint),
                  recognized.confidence > 0.20 else { continue }
            points.append(
                HandPoint(
                    joint: joint,
                    point: CGPoint(x: recognized.location.x, y: recognized.location.y),
                    confidence: recognized.confidence
                )
            )
        }
        guard points.contains(where: { $0.joint == .wrist }),
              points.contains(where: { $0.joint == .middleTip }) else {
            return nil
        }
        let confidence = points.reduce(0) { $0 + $1.confidence } / Float(points.count)
        return HandFrame(points: points, confidence: confidence, timestamp: timestamp)
    }

    private static let jointMap: [(VNHumanHandPoseObservation.JointName, HandJoint)] = [
        (.wrist, .wrist),
        (.thumbTip, .thumbTip),
        (.thumbIP, .thumbIP),
        (.thumbMP, .thumbMP),
        (.thumbCMC, .thumbCMC),
        (.indexTip, .indexTip),
        (.indexPIP, .indexPIP),
        (.indexMCP, .indexMCP),
        (.middleTip, .middleTip),
        (.middlePIP, .middlePIP),
        (.middleMCP, .middleMCP),
        (.ringTip, .ringTip),
        (.ringPIP, .ringPIP),
        (.ringMCP, .ringMCP),
        (.littleTip, .littleTip),
        (.littlePIP, .littlePIP),
        (.littleMCP, .littleMCP)
    ]
}
