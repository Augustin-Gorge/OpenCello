import Foundation

struct PitchEstimate {
    var frequency: Double?
    var confidence: Double
    var rms: Double
}

/// Implémentation YIN (De Cheveigné & Kawahara, 2002) en Swift pur.
/// Fenêtre par défaut : 2048 échantillons — assez pour descendre à ~55 Hz à 48 kHz.
final class PitchTracker {
    let sampleRate: Double
    let windowSize: Int
    let hopSize: Int
    let fMin: Double
    let fMax: Double

    private let threshold: Float = 0.12
    private let minTau: Int
    private let maxTau: Int

    init(sampleRate: Double,
         windowSize: Int = 2048,
         hopSize: Int = 1024,
         fMin: Double = 55,
         fMax: Double = 1200) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.hopSize = hopSize
        self.fMin = fMin
        self.fMax = fMax
        self.minTau = max(2, Int(sampleRate / fMax))
        self.maxTau = min(windowSize / 2 - 1, Int(sampleRate / fMin))
    }

    func estimate(_ samples: [Float]) -> PitchEstimate {
        let count = min(samples.count, windowSize)
        guard count >= 256 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: 0)
        }

        var sumSquares: Float = 0
        for value in samples.prefix(count) {
            sumSquares += value * value
        }
        let rms = Double((sumSquares / Float(count)).squareRoot())

        let half = count / 2
        var difference = [Float](repeating: 0, count: half)
        for tau in 0..<half {
            var sum: Float = 0
            var index = 0
            while index < half {
                let delta = samples[index] - samples[index + tau]
                sum += delta * delta
                index += 1
            }
            difference[tau] = sum
        }

        var normalized = [Float](repeating: 1, count: half)
        var runningSum: Float = 0
        var bestTau = -1
        var bestValue = Float.greatestFiniteMagnitude
        var thresholdTau = -1

        for tau in 1..<half {
            runningSum += difference[tau]
            normalized[tau] = runningSum > 0 ? difference[tau] * Float(tau) / runningSum : 1
            guard tau >= minTau, tau <= maxTau else { continue }
            if normalized[tau] < bestValue {
                bestValue = normalized[tau]
                bestTau = tau
            }
            if thresholdTau == -1, normalized[tau] < threshold {
                thresholdTau = tau
            }
        }

        guard bestTau > 1, bestValue < 0.9 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let chosen = thresholdTau > 0 ? thresholdTau : bestTau

        // Interpolation parabolique autour du minimum.
        let before = normalized[chosen - 1]
        let current = normalized[chosen]
        let after = chosen + 1 < half ? normalized[chosen + 1] : normalized[chosen]
        let denominator = before - 2 * current + after
        let shift: Float = abs(denominator) > 0.0001 ? (before - after) / (2 * denominator) : 0
        let period = Double(chosen) + Double(max(-1, min(1, shift)))
        guard period > 0 else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let frequency = sampleRate / period
        guard frequency >= fMin, frequency <= fMax else {
            return PitchEstimate(frequency: nil, confidence: 0, rms: rms)
        }

        let confidence = max(0, min(1, 1 - Double(current)))
        return PitchEstimate(frequency: frequency, confidence: confidence, rms: rms)
    }
}

enum NoteNamer {
    static let names = ["Do", "Do♯", "Ré", "Ré♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"]

    static func name(forMidi midi: Int) -> String {
        let pitchClass = ((midi % 12) + 12) % 12
        let octave = Int(floor(Double(midi) / 12.0)) - 1
        return "\(names[pitchClass])\(octave)"
    }

    static func note(for frequency: Double, a4: Double = 440) -> (name: String, octave: Int, cents: Double) {
        let midi = 69 + 12 * log2(frequency / a4)
        let rounded = Int(midi.rounded())
        let cents = (midi - Double(rounded)) * 100
        let pitchClass = ((rounded % 12) + 12) % 12
        let octave = Int(floor(Double(rounded) / 12.0)) - 1
        return (names[pitchClass], octave, cents)
    }
}
