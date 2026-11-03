import Foundation
import AVFoundation
import Vision
import CoreGraphics

/// Test hors app d'une vidéo en **cadre fixe** : détection du corps, des mains,
/// angle de main, doigt presseur et indice de position. Aucune vidéo n'est
/// copiée ni envoyée : le fichier est seulement lu localement.
///
/// Usage :
///   ./build/qa/fixed_frame_test chemin/vers/video.mov [sortie.csv]
///
/// Le cadrage recommandé est décrit dans docs/19-protocole-test-cadre-fixe.md.
@main
struct FixedFrameTest {
    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else {
            print("USAGE: fixed_frame_test <video.mov|mp4> [sortie.csv]")
            exit(2)
        }
        let videoURL = URL(fileURLWithPath: arguments[1])
        let csvURL = arguments.count >= 3 ? URL(fileURLWithPath: arguments[2]) : nil

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("VIDEO INTROUVABLE:", videoURL.path)
            exit(2)
        }

        await run(videoURL: videoURL, csvURL: csvURL)
    }

    static func run(videoURL: URL, csvURL: URL?) async {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            print("VIDEO: aucune piste vidéo")
            return
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            print("VIDEO: impossible d'ouvrir le lecteur")
            return
        }
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            print("VIDEO: sortie non supportée")
            return
        }
        reader.add(output)
        guard reader.startReading() else {
            print("VIDEO: lecture impossible —", reader.error?.localizedDescription ?? "?")
            return
        }

        let analyzer = PoseAnalyzer()
        let leftHandAnalyzer = LeftHandAnalyzer()
        leftHandAnalyzer.thresholds = PostureRules.handThresholds(for: .intermediate)

        var frames = 0
        var bodyFrames = 0
        var handFrames = 0
        var leftHandFrames = 0
        var validAngleFrames = 0
        var angleSum = 0.0
        var angleMax = 0.0
        var pressers: [Int: Int] = [:]
        var positionHints: [Int: Int] = [:]
        var thumbFrames = 0
        var a17Frames = 0
        var a19Frames = 0
        var lastTimestamp = -1.0
        var csvLines = ["timestamp,body,hands,left_hand,angle_deg,presser,position_hint,a17,a19,thumb_hypothesis"]

        while reader.status == .reading {
            guard let sample = output.copyNextSampleBuffer() else { break }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard timestamp.isFinite else { continue }
            // 10 fps suffisent pour les statistiques ; la vidéo peut être à 30/60 fps.
            guard timestamp - lastTimestamp >= 0.1 else { continue }
            lastTimestamp = timestamp
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }

            frames += 1
            if frames % 10 == 0 {
                print("… frame \(frames) à \(String(format: "%.2f", timestamp)) s")
            }
            guard let frame = analyzer.analyze(pixelBuffer: imageBuffer, timestamp: timestamp) else {
                csvLines.append("\(timestamp),0,0,0,,,0,,,")
                continue
            }

            let bodyDetected = !frame.landmarks.isEmpty
            if bodyDetected { bodyFrames += 1 }
            if !frame.hands.isEmpty { handFrames += 1 }

            let body = bodyReference(from: frame)
            let metrics = leftHandAnalyzer.analyze(
                hands: frame.hands,
                body: body,
                timestamp: timestamp
            )
            if metrics != nil { leftHandFrames += 1 }
            if let metrics, metrics.valid, let angle = metrics.handAngleDegrees {
                validAngleFrames += 1
                angleSum += angle
                angleMax = max(angleMax, angle)
            }
            if let presser = metrics?.presserFinger {
                pressers[presser, default: 0] += 1
            }
            if let hint = metrics?.positionHint {
                positionHints[hint, default: 0] += 1
            }
            if metrics?.thumbHypothesis == true { thumbFrames += 1 }
            if metrics?.flags["A17"] == true { a17Frames += 1 }
            if metrics?.flags["A19"] == true { a19Frames += 1 }

            csvLines.append(
                "\(String(format: "%.3f", timestamp)),\(bodyDetected ? 1 : 0),\(frame.hands.count),\(metrics == nil ? 0 : 1),\(metrics?.handAngleDegrees.map { String(format: "%.1f", $0) } ?? ""),\(metrics?.presserFinger.map(String.init) ?? ""),\(metrics?.positionHint.map(String.init) ?? ""),\(metrics?.flags["A17"] == true ? 1 : 0),\(metrics?.flags["A19"] == true ? 1 : 0),\(metrics?.thumbHypothesis == true ? 1 : 0)"
            )
        }

        if let csvURL {
            let text = csvLines.joined(separator: "\n") + "\n"
            try? text.write(to: csvURL, atomically: true, encoding: .utf8)
        }

        let frameCount = max(1, frames)
        let angleMean = validAngleFrames > 0 ? angleSum / Double(validAngleFrames) : 0
        print("VIDEO:", videoURL.lastPathComponent)
        print("FRAMES:", frames)
        print(String(format: "CORPS: %.1f %% · MAINS: %.1f %% · MAIN GAUCHE: %.1f %% · ANGLE VALIDE: %.1f %%",
                     Double(bodyFrames) / Double(frameCount) * 100,
                     Double(handFrames) / Double(frameCount) * 100,
                     Double(leftHandFrames) / Double(frameCount) * 100,
                     Double(validAngleFrames) / Double(frameCount) * 100))
        print(String(format: "ANGLE: moyenne %.1f° · max %.1f°", angleMean, angleMax))
        print("PRESSEUR:", distribution(pressers))
        print("POSITION (indice):", distribution(positionHints))
        print(String(format: "A17: %.1f %% · A19: %.1f %% · A18 (hypothèse): %.1f %%",
                     Double(a17Frames) / Double(frameCount) * 100,
                     Double(a19Frames) / Double(frameCount) * 100,
                     Double(thumbFrames) / Double(frameCount) * 100))
        if let csvURL {
            print("CSV:", csvURL.path)
        }
    }

    static func bodyReference(from frame: PoseFrame) -> BodyReference {
        var lookup: [VNHumanBodyPoseObservation.JointName: Landmark] = [:]
        for landmark in frame.landmarks {
            lookup[landmark.joint] = landmark
        }
        return BodyReference(
            leftShoulder: lookup[.leftShoulder]?.point,
            leftElbow: lookup[.leftElbow]?.point,
            leftWrist: lookup[.leftWrist]?.point,
            shoulderWidth: frame.metrics.valid ? frame.metrics.shoulderWidth : nil
        )
    }

    static func distribution(_ values: [Int: Int]) -> String {
        guard !values.isEmpty else { return "—" }
        return values
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: " ")
    }
}
