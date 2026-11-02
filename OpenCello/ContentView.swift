import SwiftUI
import AppKit
import AVFoundation
import Vision

struct ContentView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var mode: AppMode = .free
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(AppMode.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 460)

                Spacer()

                if mode == .piece && engine.pieceRunning {
                    Text("Suivi en cours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Aide et tutoriels")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Réglages")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            switch mode {
            case .free:
                FreeSessionView()
            case .piece:
                PieceView()
            case .exercises:
                ExercisesView()
            case .progress:
                ReportsView()
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .onChange(of: mode) { _, newMode in
            engine.switchMode(to: newMode)
        }
        .onAppear {
            if !engine.settings.hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: engine.settings) {
                engine.applySettings()
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                engine.settings.hasSeenOnboarding = true
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }
}

struct FreeSessionView: View {
    @EnvironmentObject private var engine: SessionEngine

    var body: some View {
        HSplitView {
            previewPane
            sidebar
        }
        .frame(minWidth: 980, minHeight: 600)
    }

    // MARK: - Aperçu caméra

    private var previewPane: some View {
        ZStack(alignment: .topLeading) {
            CameraPreview(
                camera: engine.camera,
                landmarks: engine.analysisMode == .posture ? engine.overlayLandmarks : []
            )
            .background(Color.black)

            if engine.analysisMode == .bow {
                BowOverlay()
            }

            if engine.phase == .calibrating {
                banner(text: "Calibration en cours — restez en position de jeu neutre (3 s)", color: .blue)
                    .padding(12)
            } else if engine.bowCalibrationActive {
                banner(text: "Cliquez sur le chevalet, puis sur le bout de la touche", color: .blue)
                    .padding(12)
            } else if let bowAlert = engine.bowAlert {
                banner(text: bowAlert, color: .orange)
                    .padding(12)
            } else if engine.analysisMode == .bow && engine.bowReference == nil {
                banner(text: "Cadrez de profil, puis calibrez le chevalet et la touche", color: .gray)
                    .padding(12)
            } else if !engine.alerts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(engine.alerts) { alert in
                        AlertBanner(alert: alert)
                    }
                }
                .padding(12)
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text(engine.cameraStatus)
                        .font(.caption2)
                        .padding(6)
                        .background(Color.black.opacity(0.55))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    Spacer()
                    Text("vue non miroir — l'épaule droite du musicien apparaît à gauche")
                        .font(.caption2)
                        .padding(6)
                        .background(Color.black.opacity(0.55))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .padding(12)
            }
        }
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.callout)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.85)))
            .foregroundColor(.white)
    }

    // MARK: - Panneau latéral

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusSection
            analysisSection
            pitchSection
            if let feedback = engine.lastNoteFeedback {
                lastNoteCard(feedback)
            }
            if engine.analysisMode == .bow {
                if let feedback = engine.bowFeedback {
                    bowCard(feedback)
                } else {
                    Text("Archet non détecté — vérifiez le cadrage de profil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            controls
            Divider()
            if engine.phase == .report {
                reportSection
            } else {
                helpSection
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenCello").font(.title2.bold())
                Text("Posture + son, en local").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if engine.phase == .running {
                Text(engine.elapsedText)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            statusRow(engine.cameraRunning ? .green : .gray, text: engine.cameraStatus)
            statusRow(engine.micRunning ? .green : .gray, text: engine.micStatus)
            statusRow(engine.rules.baseline == nil ? .orange : .green, text: engine.baselineStatus)
        }
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Analyse caméra").font(.caption.bold()).foregroundStyle(.secondary)
            Picker(
                "Analyse caméra",
                selection: Binding(
                    get: { engine.analysisMode },
                    set: { engine.setAnalysisMode($0) }
                )
            ) {
                ForEach(AnalysisMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(engine.phase != .idle)
        }
    }

    private func statusRow(_ color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    private var pitchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hauteur").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(engine.pitchText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                Text(engine.pitchDetail)
                    .font(.callout)
                    .foregroundStyle(engine.pitchColor)
            }
            ProgressView(value: engine.rms)
                .tint(engine.rms > 0.6 ? .orange : .green)
            Text("Niveau d'entrée micro").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func lastNoteCard(_ feedback: NoteFeedback) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dernière note").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(feedback.name).font(.title3.weight(.semibold))
                Text(String(format: "%+.0f cents", feedback.cents))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(feedback.accuracy.color)
                Spacer()
                Text(feedback.accuracy.label)
                    .font(.caption.bold())
                    .foregroundStyle(feedback.accuracy.color)
            }
            Text(String(format: "Stabilité %.0f cents · HNR %.0f dB%@",
                        feedback.stability,
                        feedback.hnr,
                        feedback.isStable ? " · stable" : " · instable"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let rate = feedback.vibratoRate, let extent = feedback.vibratoExtent {
                Text(String(format: "Vibrato %.1f Hz · ±%.0f cents", rate, extent / 2))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let articulation = feedback.articulation {
                Text("Articulation : \(articulation.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func bowCard(_ feedback: BowEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Archet").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Angle").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.0f°", feedback.angleDeviation))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(feedback.angleOK ? .green : .orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.0f %%", feedback.contact * 100))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(feedback.zoneOK ? .green : .orange)
                }
                Spacer()
                Text(feedback.angleOK && feedback.zoneOK ? "OK" : "À corriger")
                    .font(.caption.bold())
                    .foregroundStyle(feedback.angleOK && feedback.zoneOK ? .green : .orange)
            }
            Text(String(format: "Confiance %.0f %% · zone chevalet-touche", feedback.confidence * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 8) {
                if engine.analysisMode == .posture {
                    Button {
                        engine.startCalibration()
                    } label: {
                        Label("Calibrer la posture (3 s)", systemImage: "scope")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        engine.startBowCalibration()
                    } label: {
                        Label("Calibrer le profil (2 clics)", systemImage: "scope")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    engine.startSession()
                } label: {
                    Label("Démarrer une séance", systemImage: "record.circle")
                }
                .buttonStyle(.bordered)
                .disabled(engine.analysisMode == .bow && engine.bowReference == nil)

                Text(engine.analysisMode == .posture
                     ? "Asseyez-vous comme pour jouer, épaules basses, puis calibrez."
                     : "Caméra de profil : cliquez le chevalet puis le bout de la touche avant de jouer.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .calibrating:
            HStack {
                ProgressView().controlSize(.small)
                Text("Calibration…").font(.caption)
                Spacer()
                Button("Annuler") { engine.cancelCalibration() }
                    .buttonStyle(.link)
            }

        case .running:
            VStack(alignment: .leading, spacing: 8) {
                Button(role: .destructive) {
                    engine.stopSession()
                } label: {
                    Label("Arrêter et générer le rapport", systemImage: "stop.circle")
                }
                .buttonStyle(.borderedProminent)
                if let message = engine.message {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }

        case .report:
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    engine.openReport()
                } label: {
                    Label("Ouvrir le rapport", systemImage: "doc.text")
                }
                .buttonStyle(.borderedProminent)
                .disabled(engine.reportPath == nil)

                Button {
                    engine.newSession()
                } label: {
                    Label("Nouvelle séance", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rapport de séance").font(.caption.bold()).foregroundStyle(.secondary)
            ScrollView {
                Text(engine.reportMarkdown)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
            if let path = engine.reportPath {
                Text(path.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ce qui est analysé").font(.caption.bold()).foregroundStyle(.secondary)
            Text("""
            • Tête en avant (proxy 2D)
            • Épaules haussées / voûtées
            • Asymétrie des épaules
            • Hauteur du son (YIN) et cents
            """)
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Limites : lumière, angle caméra, bruit. Les données restent sur ce Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bannière d'alerte

struct AlertBanner: View {
    let alert: ActiveAlert

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title).font(.headline)
                Text(alert.message).font(.caption)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.6), lineWidth: 1))
        .frame(maxWidth: 380, alignment: .leading)
    }
}

// MARK: - Aperçu caméra (AVFoundation + overlay Vision)

struct CameraPreview: NSViewRepresentable {
    typealias NSViewType = CameraPreviewContainer

    let camera: CameraManager
    let landmarks: [Landmark]

    func makeNSView(context: Context) -> CameraPreviewContainer {
        let view = CameraPreviewContainer()
        view.overlay.frame = view.bounds
        view.overlay.autoresizingMask = [.width, .height]
        view.addSubview(view.overlay)
        return view
    }

    func updateNSView(_ view: CameraPreviewContainer, context: Context) {
        view.attach(previewLayer: camera.previewLayer)
        view.overlay.landmarks = landmarks
        view.overlay.needsDisplay = true
    }
}

final class CameraPreviewContainer: NSView {
    let overlay = PoseOverlayView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(previewLayer: AVCaptureVideoPreviewLayer?) {
        guard let previewLayer else { return }
        if previewLayer.superlayer !== layer {
            previewLayer.removeFromSuperlayer()
            layer?.insertSublayer(previewLayer, at: 0)
        }
        previewLayer.frame = bounds
    }

    override func layout() {
        super.layout()
        layer?.sublayers?.forEach { $0.frame = bounds }
        overlay.frame = bounds
    }
}

final class PoseOverlayView: NSView {
    var landmarks: [Landmark] = []

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, !landmarks.isEmpty else { return }

        var lookup: [VNHumanBodyPoseObservation.JointName: Landmark] = [:]
        for landmark in landmarks {
            lookup[landmark.joint] = landmark
        }

        let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.neck, .nose), (.neck, .leftEar), (.neck, .rightEar),
            (.neck, .leftShoulder), (.neck, .rightShoulder),
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist)
        ]

        context.setLineWidth(3)
        context.setLineCap(.round)

        for (first, second) in bones {
            guard let start = lookup[first], let end = lookup[second] else { continue }
            let isRightArm = first == .rightShoulder || first == .rightElbow
                || second == .rightShoulder || second == .rightElbow || second == .rightWrist
            context.setStrokeColor(
                isRightArm
                    ? NSColor.systemRed.withAlphaComponent(0.9).cgColor
                    : NSColor.white.withAlphaComponent(0.75).cgColor
            )
            context.move(to: point(for: start))
            context.addLine(to: point(for: end))
            context.strokePath()
        }

        for landmark in landmarks {
            let center = point(for: landmark)
            let radius: CGFloat = 4.5
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.setFillColor(isRightSide(landmark.joint) ? NSColor.systemRed.cgColor : NSColor.white.cgColor)
            context.fillEllipse(in: rect)
        }
    }

    /// Zone vidéo réelle dans la vue (le preview est en .resizeAspect, 16:9).
    private var videoRect: CGRect {
        let targetAspect: CGFloat = 16.0 / 9.0
        let viewAspect = bounds.width / max(bounds.height, 1)
        if viewAspect > targetAspect {
            let width = bounds.height * targetAspect
            return CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: bounds.height)
        } else {
            let height = bounds.width / targetAspect
            return CGRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
        }
    }

    private func point(for landmark: Landmark) -> CGPoint {
        let rect = videoRect
        return CGPoint(
            x: rect.minX + landmark.point.x * rect.width,
            y: rect.minY + landmark.point.y * rect.height
        )
    }

    private func isRightSide(_ joint: VNHumanBodyPoseObservation.JointName) -> Bool {
        switch joint {
        case .rightShoulder, .rightElbow, .rightWrist, .rightEar:
            return true
        default:
            return false
        }
    }
}

// MARK: - Overlay archet (mode profil)

struct BowOverlay: View {
    @EnvironmentObject private var engine: SessionEngine

    var body: some View {
        GeometryReader { geometry in
            let rect = videoRect(in: geometry.size)
            ZStack {
                Canvas { context, size in
                    let video = videoRect(in: size)

                    func point(_ normalized: CGPoint) -> CGPoint {
                        CGPoint(
                            x: video.minX + normalized.x * video.width,
                            y: video.minY + normalized.y * video.height
                        )
                    }

                    if let reference = engine.bowReference {
                        var path = Path()
                        path.move(to: point(reference.bridge))
                        path.addLine(to: point(reference.fingerboard))
                        context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 2)
                    }

                    for line in engine.bowLines {
                        var path = Path()
                        path.move(to: point(line.start))
                        path.addLine(to: point(line.end))
                        context.stroke(path, with: .color(.yellow.opacity(0.35)), lineWidth: 1)
                    }

                    if let feedback = engine.bowFeedback {
                        var path = Path()
                        path.move(to: point(feedback.line.start))
                        path.addLine(to: point(feedback.line.end))
                        let color: Color = feedback.angleOK && feedback.zoneOK ? .green : .orange
                        context.stroke(path, with: .color(color), lineWidth: 3)
                    }

                    for calibrationPoint in engine.bowCalibrationPoints {
                        let center = point(calibrationPoint)
                        let circle = Path(
                            ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)
                        )
                        context.fill(circle, with: .color(.cyan))
                    }
                }
                .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            guard engine.bowCalibrationActive else { return }
                            let x = (value.location.x - rect.minX) / max(rect.width, 1)
                            let y = (value.location.y - rect.minY) / max(rect.height, 1)
                            engine.addBowCalibrationPoint(CGPoint(x: x, y: y))
                        }
                    )
            }
        }
    }

    private func videoRect(in size: CGSize) -> CGRect {
        let targetAspect: CGFloat = 16.0 / 9.0
        let viewAspect = size.width / max(size.height, 1)
        if viewAspect > targetAspect {
            let width = size.height * targetAspect
            return CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / targetAspect
            return CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        }
    }
}
