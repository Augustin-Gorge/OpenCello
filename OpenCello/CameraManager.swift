import AVFoundation
import Combine

struct CameraOption: Identifiable, Hashable {
    let id: String
    let name: String
}

enum SessionVideoStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Movies", isDirectory: true)
        return base
            .appendingPathComponent("OpenCello", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    static func makeURL(date: Date = Date()) -> URL? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return directory.appendingPathComponent("seance_\(formatter.string(from: date)).mov")
    }
}

/// Capture vidéo + inférence de pose. Tout reste local.
final class CameraManager: NSObject, ObservableObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureFileOutputRecordingDelegate {

    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var cameras: [CameraOption] = []
    @Published var selectedCameraID: String? = UserDefaults.standard.string(forKey: "camera.selectedID")
    @Published var isRecording = false

    var analysisMode: AnalysisMode = .posture
    var onPose: ((PoseFrame?) -> Void)?
    var onBow: ((ProfileFrame?) -> Void)?
    var onStatus: ((String) -> Void)?
    var onRunning: ((Bool) -> Void)?
    var onRecordingFinished: ((URL, Error?) -> Void)?

    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "opencello.video", qos: .userInteractive)
    private let analyzer = PoseAnalyzer()
    private let profileAnalyzer = ProfileAnalyzer()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var pendingRecordingURL: URL?
    private var stopAfterRecording = false
    private var currentDeviceID: String?
    private var lastProcessed: CFTimeInterval = 0
    private let minFrameInterval: CFTimeInterval = 1.0 / 15.0

    func start() {
        refreshCameras()
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
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.stopAfterRecording = true
                self.movieOutput.stopRecording()
                return
            }
            self.stopSessionLocked()
        }
    }

    /// Sélectionne une caméra et redémarre la session si elle tourne déjà.
    /// Le choix est mémorisé localement.
    func selectCamera(_ id: String?) {
        guard !isRecording else { return }
        selectedCameraID = id
        UserDefaults.standard.set(id, forKey: "camera.selectedID")
        guard isRunning else { return }
        videoQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.configureAndRun()
        }
    }

    func refreshCameras() {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external,
            .continuityCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        let options = discovery.devices.map {
            CameraOption(id: $0.uniqueID, name: $0.localizedName)
        }
        DispatchQueue.main.async { [weak self] in
            self?.cameras = options.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if let selected = UserDefaults.standard.string(forKey: "camera.selectedID"),
               !options.contains(where: { $0.id == selected }) {
                self?.selectedCameraID = nil
            }
        }
    }

    // MARK: - Enregistrement vidéo (opt-in, local)

    func startRecording(to url: URL) {
        pendingRecordingURL = url
        if isRunning {
            startPendingRecording()
        }
    }

    func stopRecording() {
        pendingRecordingURL = nil
        videoQueue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
        }
    }

    private func startPendingRecording() {
        guard let url = pendingRecordingURL, !movieOutput.isRecording else { return }
        pendingRecordingURL = nil
        videoQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                self.pendingRecordingURL = url
                return
            }
            guard self.session.outputs.contains(where: { $0 === self.movieOutput }) else {
                return
            }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRecording = false
            self.onRecordingFinished?(outputFileURL, error)
            if self.stopAfterRecording {
                self.stopAfterRecording = false
                self.videoQueue.async { self.stopSessionLocked() }
            }
        }
    }

    // MARK: - Session

    private func deny() {
        pendingRecordingURL = nil
        DispatchQueue.main.async { [weak self] in
            self?.permissionDenied = true
            self?.onRunning?(false)
            self?.onStatus?("Caméra refusée — Réglages Système > Confidentialité > Caméra")
        }
    }

    private func preferredDevice() -> AVCaptureDevice? {
        if let selectedCameraID,
           let device = AVCaptureDevice(uniqueID: selectedCameraID),
           device.hasMediaType(.video) {
            return device
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
            ?? AVCaptureDevice.default(for: .video)
    }

    private func configureAndRun() {
        videoQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720

            if let currentInput = self.session.inputs.first {
                self.session.removeInput(currentInput)
            }

            let device = self.preferredDevice()
            if let device,
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentDeviceID = device.uniqueID
            }

            if self.videoOutput == nil {
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                    self.videoOutput = output
                }
            }

            if !self.session.outputs.contains(where: { $0 === self.movieOutput }),
               self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()

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
                if self.pendingRecordingURL != nil {
                    self.startPendingRecording()
                }
            }
        }
    }

    private func stopSessionLocked() {
        guard session.isRunning else {
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.onRunning?(false)
            }
            return
        }
        session.stopRunning()
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.onRunning?(false)
            self?.onStatus?("Caméra arrêtée")
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
