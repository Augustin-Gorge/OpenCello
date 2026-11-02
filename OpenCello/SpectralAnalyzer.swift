import Foundation
import Accelerate

struct SpectralFrame {
    let centroid: Double
    let flatness: Double
    let highBandRatio: Double
    let hnr: Double
}

/// Analyse spectrale légère par fenêtre : centroïde, flatness, ratio haute bande
/// (proxy de « tristimulus » aigu) et HNR estimé sur les partiels de F0.
final class SpectralAnalyzer {
    private let sampleRate: Double
    private let fftSize: Int
    private let binCount: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]
    private var windowed: [Float]

    init(sampleRate: Double, fftSize: Int = 2048) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.binCount = fftSize / 2
        self.log2n = vDSP_Length(round(log2(Double(fftSize))))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: fftSize)
        self.windowed = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func analyze(samples: [Float], f0: Double?) -> SpectralFrame? {
        guard samples.count >= fftSize else { return nil }
        let input = Array(samples.suffix(fftSize))
        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var real = [Float](repeating: 0, count: binCount)
        var imag = [Float](repeating: 0, count: binCount)
        var magnitudes = [Float](repeating: 0, count: binCount)
        var fftOK = false

        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                guard let realBase = realPointer.baseAddress,
                      let imagBase = imagPointer.baseAddress else { return }
                var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
                windowed.withUnsafeBufferPointer { windowPointer in
                    guard let base = windowPointer.baseAddress else { return }
                    let complex = UnsafeRawPointer(base).bindMemory(to: DSPComplex.self, capacity: binCount)
                    vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(binCount))
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(binCount))
                fftOK = true
            }
        }

        guard fftOK else { return nil }

        let nyquist = sampleRate / 2
        let binWidth = nyquist / Double(binCount)
        let epsilon = 1e-9

        var magnitudeSum = 0.0
        var weightedSum = 0.0
        var logSum = 0.0
        var highSum = 0.0

        for index in 1..<binCount {
            let magnitude = Double(magnitudes[index])
            let frequency = Double(index) * binWidth
            magnitudeSum += magnitude
            weightedSum += magnitude * frequency
            logSum += log(max(magnitude, epsilon))
            if frequency > 2000 { highSum += magnitude }
        }

        guard magnitudeSum > 0 else { return nil }

        let centroid = weightedSum / magnitudeSum
        let count = Double(max(1, binCount - 1))
        let arithmeticMean = magnitudeSum / count
        let geometricMean = exp(logSum / count)
        let flatness = arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
        let highBandRatio = highSum / magnitudeSum

        var hnr = 0.0
        if let f0, f0 > 40, f0 < nyquist / 2 {
            var harmonicEnergy = 0.0
            let maxHarmonic = max(1, min(30, Int(nyquist / f0)))
            for harmonicIndex in 1...maxHarmonic {
                let bin = Int(round((f0 * Double(harmonicIndex)) / binWidth))
                guard bin > 0, bin < binCount else { continue }
                let lower = max(1, bin - 2)
                let upper = min(binCount - 1, bin + 2)
                for harmonicBin in lower...upper {
                    harmonicEnergy += Double(magnitudes[harmonicBin])
                }
            }
            let noise = max(magnitudeSum - harmonicEnergy, epsilon)
            hnr = 10 * log10(max(harmonicEnergy, epsilon) / noise)
        }

        return SpectralFrame(
            centroid: centroid,
            flatness: flatness,
            highBandRatio: highBandRatio,
            hnr: hnr
        )
    }
}
