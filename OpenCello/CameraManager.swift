import AVFoundation
import Combine

/// Capture vidéo + inférence de pose. Tout reste local.
final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    var analysisMode: AnalysisMode = .posture
    var onPose: ((PoseFrame?) -> Void)?
    var onBow: ((ProfileFrame?) -> Void)?
    var onStatus: ((String) -> Void)?
    var onRunning: ((Bool) -> Void)?

    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "opencello.video", qos: .userInteractive)
    private let analyzer = PoseAnalyzer()
    private let profileAnalyzer = ProfileAnalyzer()
    private var lastProcessed: CFTimeInterval = 0
    private let minFrameInterval: CFTimeInterval = 1.0 / 15.0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndRun()
                } else {
                    self?.deny()
                }
            }
        default:
            deny()
        }
    }

    func stop() {
        videoQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                self.onRunning?(false)
                self.onStatus?("Caméra arrêtée")
            }
        }
    }

    private func deny() {
        DispatchQueue.main.async { [weak self] in
            self?.permissionDenied = true
            self?.onRunning?(false)
            self?.onStatus?("Caméra refusée — Réglages Système > Confidentialité > Caméra")
        }
    }

    private func configureAndRun() {
        videoQueue.async { [weak self] in
            guard let self else { return }

            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720

                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                    ?? AVCaptureDevice.default(for: .video)
                if let device,
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }
                self.session.commitConfiguration()
            }

            guard !self.session.inputs.isEmpty else {
                DispatchQueue.main.async {
                    self.onRunning?(false)
                    self.onStatus?("Aucune caméra disponible")
                }
                return
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.permissionDenied = false
                self.isRunning = true
                self.onRunning?(true)
                self.onStatus?("Caméra active — détection en cours")
                if self.previewLayer == nil {
                    let layer = AVCaptureVideoPreviewLayer(session: self.session)
                    layer.videoGravity = .resizeAspect
                    self.previewLayer = layer
                }
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastProcessed >= minFrameInterval else { return }
        lastProcessed = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if analysisMode == .bow {
            let frame = profileAnalyzer.analyze(pixelBuffer: imageBuffer, timestamp: now)
            onBow?(frame)
        } else {
            let frame = analyzer.analyze(pixelBuffer: imageBuffer, timestamp: now)
            onPose?(frame)
        }
    }
}
