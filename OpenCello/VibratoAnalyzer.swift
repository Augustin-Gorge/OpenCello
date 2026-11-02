import Foundation

struct VibratoEstimate {
    let rate: Double
    let extent: Double
    let confidence: Double
}

/// Estime le vibrato à partir d'un contour de hauteur (MIDI) et de ses timestamps.
/// Dépendance : aucune.
enum VibratoAnalyzer {
    static func estimate(midis: [Double], timestamps: [TimeInterval]) -> VibratoEstimate? {
        guard midis.count >= 12, midis.count == timestamps.count else { return nil }
        guard let first = timestamps.first, let last = timestamps.last, last > first else { return nil }
        let duration = last - first
        guard duration >= 0.4 else { return nil }

        let count = Double(midis.count)
        let meanTime = timestamps.reduce(0, +) / count
        let meanMidi = midis.reduce(0, +) / count

        var numerator = 0.0
        var denominator = 0.0
        for index in 0..<midis.count {
            let dt = timestamps[index] - meanTime
            numerator += dt * (midis[index] - meanMidi)
            denominator += dt * dt
        }
        let slope = denominator > 0 ? numerator / denominator : 0

        var cents = (0..<midis.count).map { index in
            (midis[index] - (meanMidi + slope * (timestamps[index] - meanTime))) * 100
        }
        let meanCents = cents.reduce(0, +) / count
        cents = cents.map { $0 - meanCents }

        let rms = (cents.map { $0 * $0 }.reduce(0, +) / count).squareRoot()
        guard rms > 3 else { return nil }

        let sampleInterval = duration / Double(midis.count - 1)
        let minLag = max(2, Int(0.08 / sampleInterval))
        let maxLag = min(midis.count / 2, Int(0.5 / sampleInterval))
        guard maxLag > minLag else { return nil }

        var bestLag = 0
        var bestCorrelation = 0.0

        for lag in minLag...maxLag {
            var sum = 0.0
            for index in 0..<(cents.count - lag) {
                sum += cents[index] * cents[index + lag]
            }
            let correlation = sum / Double(cents.count - lag) / (rms * rms)
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestCorrelation > 0.3, bestLag > 0 else { return nil }

        let rate = 1.0 / (Double(bestLag) * sampleInterval)
        let extent = 2 * 2.0.squareRoot() * rms
        guard rate >= 2, rate <= 12 else { return nil }

        return VibratoEstimate(rate: rate, extent: extent, confidence: bestCorrelation)
    }
}
