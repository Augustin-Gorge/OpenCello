import AVFoundation
import Combine
import QuartzCore

struct PitchFrame {
    let frequency: Double?
    let confidence: Double
    let rms: Double
    let timestamp: TimeInterval
}

/// Capture micro + estimation de hauteur YIN. Tout reste local.
final class MicrophoneManager: ObservableObject {
    @Published var isRunning = false
    @Published var permissionDenied = false

    var onPitch: ((PitchFrame) -> Void)?
    var onSegment: ((SegmenterOutput) -> Void)?
    var onStatus: ((String) -> Void)?
    var onRunning: ((Bool) -> Void)?

    private let engine = AVAudioEngine()
    private var tracker: PitchTracker?
    private var spectralAnalyzer: SpectralAnalyzer?
    private let segmenter = NoteSegmenter()
    private var buffer: [Float] = []
    private var samplesSinceLastAnalysis = 0
    private var recentFrequencies: [Double] = []
    private let maxBuffer = 16_384

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    self?.begin()
                } else {
                    self?.deny()
                }
            }
        default:
            deny()
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        buffer.removeAll()
        recentFrequencies.removeAll()
        segmenter.reset()
        onRunning?(false)
        onStatus?("Micro arrêté")
    }

    private func deny() {
        DispatchQueue.main.async { [weak self] in
            self?.permissionDenied = true
            self?.onRunning?(false)
            self?.onStatus?("Micro refusé — Réglages Système > Confidentialité > Microphone")
        }
    }

    private func begin() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isRunning else { return }

            let input = self.engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                self.onStatus?("Aucun périphérique d'entrée audio")
                return
            }

            self.tracker = PitchTracker(sampleRate: format.sampleRate)
            self.spectralAnalyzer = SpectralAnalyzer(sampleRate: format.sampleRate)
            self.buffer.removeAll()
            self.samplesSinceLastAnalysis = 0

            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] pcmBuffer, _ in
                self?.process(pcmBuffer)
            }

            self.engine.prepare()
            do {
                try self.engine.start()
                self.isRunning = true
                self.permissionDenied = false
                self.onRunning?(true)
                self.onStatus?("Micro actif — analyse du son")
            } catch {
                input.removeTap(onBus: 0)
                self.onStatus?("Impossible de démarrer le micro : \(error.localizedDescription)")
            }
        }
    }

    private func process(_ pcmBuffer: AVAudioPCMBuffer) {
        guard let channels = pcmBuffer.floatChannelData else { return }
        let frameCount = Int(pcmBuffer.frameLength)
        guard frameCount > 0 else { return }
        let channelCount = Int(pcmBuffer.format.channelCount)

        var mono = [Float](repeating: 0, count: frameCount)
        if channelCount == 1 {
            mono.withUnsafeMutableBufferPointer { destination in
                destination.baseAddress?.update(from: channels[0], count: frameCount)
            }
        } else {
            for index in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channels[channel][index]
                }
                mono[index] = sum / Float(channelCount)
            }
        }

        buffer.append(contentsOf: mono)
        if buffer.count > maxBuffer {
            buffer.removeFirst(buffer.count - maxBuffer)
        }

        samplesSinceLastAnalysis += frameCount
        guard let tracker,
              buffer.count >= tracker.windowSize,
              samplesSinceLastAnalysis >= tracker.hopSize else { return }
        samplesSinceLastAnalysis = 0

        let window = Array(buffer.suffix(tracker.windowSize))
        let estimate = tracker.estimate(window)
        let timestamp = CACurrentMediaTime()

        let spectral = spectralAnalyzer?.analyze(samples: window, f0: estimate.frequency)

        let frequency: Double?
        if estimate.rms < 0.012 {
            frequency = nil
        } else {
            frequency = smoothed(estimate.frequency, confidence: estimate.confidence)
        }

        let frame = PitchFrame(
            frequency: frequency,
            confidence: estimate.confidence,
            rms: estimate.rms,
            timestamp: timestamp
        )
        onPitch?(frame)

        for output in segmenter.add(frame, spectral: spectral) {
            onSegment?(output)
        }
    }

    private func smoothed(_ frequency: Double?, confidence: Double) -> Double? {
        guard let frequency, confidence > 0.7 else {
            return recentFrequencies.last
        }
        recentFrequencies.append(frequency)
        if recentFrequencies.count > 7 {
            recentFrequencies.removeFirst()
        }
        let sorted = recentFrequencies.sorted()
        return sorted[sorted.count / 2]
    }
}
