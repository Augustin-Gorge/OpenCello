import Foundation
import CoreGraphics

struct HoughLine {
    /// Angle normal en radians, dans [0, π).
    let theta: Double
    /// Distance signée à l'origine, en pixels.
    let rho: Double
    /// Nombre de votes (support de la ligne).
    let support: Int
}

/// Détection de lignes par transformée de Hough sur une image grayscale.
/// Volontairement simple : downsampling côté appelant, Sobel + Hough.
enum LineDetector {
    static func detect(
        gray: [UInt8],
        width: Int,
        height: Int,
        edgeThreshold: Int = 55,
        maxLines: Int = 8
    ) -> [HoughLine] {
        guard width > 16, height > 16, gray.count == width * height else { return [] }

        var edges: [(Int, Int)] = []
        edges.reserveCapacity(width * height / 8)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let gx = -Int(gray[index - width - 1]) - 2 * Int(gray[index - 1]) - Int(gray[index + width - 1])
                    + Int(gray[index - width + 1]) + 2 * Int(gray[index + 1]) + Int(gray[index + width + 1])
                let gy = -Int(gray[index - width - 1]) - 2 * Int(gray[index - width]) - Int(gray[index - width + 1])
                    + Int(gray[index + width - 1]) + 2 * Int(gray[index + width]) + Int(gray[index + width + 1])
                if abs(gx) + abs(gy) > edgeThreshold {
                    edges.append((x, y))
                }
            }
        }

        guard edges.count > 30 else { return [] }

        let thetaCount = 90
        let diagonal = Int(ceil(hypot(Double(width), Double(height))))
        let rhoCount = diagonal * 2 + 1
        var accumulator = [Int](repeating: 0, count: thetaCount * rhoCount)

        var cosTable = [Double](repeating: 0, count: thetaCount)
        var sinTable = [Double](repeating: 0, count: thetaCount)
        for index in 0..<thetaCount {
            let theta = Double(index) * .pi / Double(thetaCount)
            cosTable[index] = cos(theta)
            sinTable[index] = sin(theta)
        }

        for (x, y) in edges {
            for thetaIndex in 0..<thetaCount {
                let rho = Double(x) * cosTable[thetaIndex] + Double(y) * sinTable[thetaIndex]
                let rhoIndex = Int(round(rho)) + diagonal
                guard rhoIndex >= 0, rhoIndex < rhoCount else { continue }
                accumulator[thetaIndex * rhoCount + rhoIndex] += 1
            }
        }

        var lines: [HoughLine] = []
        for _ in 0..<maxLines {
            var bestValue = 0
            var bestTheta = 0
            var bestRho = 0
            for thetaIndex in 0..<thetaCount {
                let base = thetaIndex * rhoCount
                for rhoIndex in 0..<rhoCount {
                    let value = accumulator[base + rhoIndex]
                    if value > bestValue {
                        bestValue = value
                        bestTheta = thetaIndex
                        bestRho = rhoIndex
                    }
                }
            }
            guard bestValue >= 20 else { break }

            lines.append(
                HoughLine(
                    theta: Double(bestTheta) * .pi / Double(thetaCount),
                    rho: Double(bestRho - diagonal),
                    support: bestValue
                )
            )

            for deltaTheta in -2...2 {
                for deltaRho in -4...4 {
                    let thetaIndex = bestTheta + deltaTheta
                    let rhoIndex = bestRho + deltaRho
                    guard thetaIndex >= 0, thetaIndex < thetaCount,
                          rhoIndex >= 0, rhoIndex < rhoCount else { continue }
                    accumulator[thetaIndex * rhoCount + rhoIndex] = 0
                }
            }
        }

        return lines
    }

    /// Convertit une ligne (theta, rho) en segment coupé aux bords de l'image.
    static func segment(for line: HoughLine, width: Double, height: Double) -> (CGPoint, CGPoint)? {
        let cosTheta = cos(line.theta)
        let sinTheta = sin(line.theta)
        let point = CGPoint(x: line.rho * cosTheta, y: line.rho * sinTheta)
        let direction = CGVector(dx: -sinTheta, dy: cosTheta)

        var candidates: [CGPoint] = []

        if abs(direction.dx) > 1e-6 {
            for x in [0.0, width] {
                let t = (x - point.x) / direction.dx
                let y = point.y + t * direction.dy
                if y >= 0, y <= height {
                    candidates.append(CGPoint(x: x, y: y))
                }
            }
        }
        if abs(direction.dy) > 1e-6 {
            for y in [0.0, height] {
                let t = (y - point.y) / direction.dy
                let x = point.x + t * direction.dx
                if x >= 0, x <= width {
                    candidates.append(CGPoint(x: x, y: y))
                }
            }
        }

        guard candidates.count >= 2 else { return nil }

        var first = candidates[0]
        var second = candidates[1]
        var maxDistance = hypot(second.x - first.x, second.y - first.y)

        for i in 0..<candidates.count {
            for j in (i + 1)..<candidates.count {
                let distance = hypot(candidates[j].x - candidates[i].x, candidates[j].y - candidates[i].y)
                if distance > maxDistance {
                    maxDistance = distance
                    first = candidates[i]
                    second = candidates[j]
                }
            }
        }

        guard maxDistance > 10 else { return nil }
        return (first, second)
    }
}
