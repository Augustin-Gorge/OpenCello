import SwiftUI
import AppKit
import AVFoundation
import Vision

struct ContentView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showHelp = false

    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { engine.appMode },
            set: { engine.switchMode(to: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Mode", selection: modeBinding) {
                    ForEach(AppMode.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 620)

                Spacer()

                if engine.appMode == .piece && engine.pieceRunning {
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

            switch engine.appMode {
            case .free:
                FreeSessionView()
            case .piece:
                PieceView()
            case .exercises:
                ExercisesView()
            case .reports:
                ReportsView()
            case .profile:
                ProfileView()
            }
        }
        .frame(minWidth: 980, minHeight: 640)
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

// MARK: - Séance libre plein écran

/// La caméra occupe toute la zone de travail ; les contrôles et le feedback
/// en temps réel flottent par-dessus (HUD), façon « miroir augmenté ».
struct FreeSessionView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var showLivePanel = true

    var body: some View {
        ZStack {
            Color.black

            CameraPreview(
                camera: engine.camera,
                landmarks: engine.analysisMode == .posture ? engine.overlayLandmarks : []
            )

            if engine.analysisMode == .bow {
                BowOverlay()
            }

            topOverlay
                .frame(maxHeight: .infinity, alignment: .top)

            if engine.phase == .idle, !engine.bowCalibrationActive {
                idleOverlay
            }

            if engine.phase == .calibrating || engine.phase == .running {
                bottomBar
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            if showLivePanel, engine.phase == .running {
                livePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bandeau supérieur (alertes + statut)

    private var topOverlay: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if engine.phase == .calibrating {
                    banner(text: "Calibration en cours — restez en position de jeu neutre (3 s)", color: .blue)
                } else if engine.bowCalibrationActive {
                    banner(text: "Cliquez sur le chevalet, puis sur le bout de la touche", color: .blue)
                } else if let bowAlert = engine.bowAlert {
                    banner(text: bowAlert, color: .orange)
                } else if engine.analysisMode == .bow, engine.bowReference == nil, engine.phase == .idle {
                    banner(text: "Cadrez de profil, puis calibrez le chevalet et la touche", color: .gray)
                } else if !engine.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.alerts) { alert in
                            AlertBanner(alert: alert)
                        }
                    }
                } else if engine.phase == .running {
                    banner(text: "Posture et son suivis — jouez librement", color: .green.opacity(0.8))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 8) {
                    if engine.phase == .running {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text(engine.elapsedText)
                                .font(.title3.monospacedDigit().weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.55)))
                        .foregroundStyle(.white)
                    }

                    if engine.phase == .running {
                        Button {
                            showLivePanel.toggle()
                        } label: {
                            Image(systemName: showLivePanel ? "sidebar.right" : "sidebar.right.slash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(.black.opacity(0.55)))
                        .help(showLivePanel ? "Masquer le panneau de position" : "Afficher le panneau de position")
                    }

                    Button {
                        toggleFullScreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(.black.opacity(0.55)))
                    .help("Plein écran (Échap pour revenir)")
                }

                statusChips
            }
        }
        .padding(14)
    }

    private var statusChips: some View {
        HStack(spacing: 8) {
            chip(color: engine.cameraRunning ? .green : .gray, icon: "video", text: "Caméra")
            chip(color: engine.micRunning ? .green : .gray, icon: "mic", text: "Micro")
            if engine.analysisMode == .bow {
                chip(color: engine.bowReference == nil ? .orange : .green, icon: "scope", text: engine.bowReference == nil ? "Profil non calibré" : "Profil calibré")
            } else {
                chip(color: engine.rules.baseline == nil ? .orange : .green, icon: "scope", text: engine.rules.baseline == nil ? "Posture non calibrée" : "Posture calibrée")
            }
        }
    }

    private func chip(color: Color, icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.55)))
        .foregroundStyle(.white)
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.callout)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.85)))
            .foregroundColor(.white)
    }

    // MARK: - Carte centrale (au repos)

    private var idleOverlay: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Séance libre").font(.title2.bold())
                Text("La caméra occupe tout l'écran. Placez-vous face à elle (ou de profil pour l'archet), puis lancez-vous.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
            .frame(maxWidth: 320)

            HStack(spacing: 12) {
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
            }

            Text(engine.analysisMode == .posture
                 ? "Asseyez-vous comme pour jouer, épaules basses, puis calibrez."
                 : "Caméra de profil : cliquez le chevalet puis le bout de la touche avant de jouer.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Analysé : tête en avant, épaules haussées/voûtées, asymétrie, hauteur du son (YIN) ; archet et cordes en vue profil. Tout reste sur ce Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Barre inférieure (pendant la séance)

    private var bottomBar: some View {
        HStack(spacing: 24) {
            phaseControls
            Spacer()
            pitchBlock
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(16)
    }

    @ViewBuilder
    private var phaseControls: some View {
        switch engine.phase {
        case .calibrating:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Calibration…").font(.callout)
                Button("Annuler") { engine.cancelCalibration() }
                    .buttonStyle(.link)
            }
        case .running:
            VStack(alignment: .leading, spacing: 6) {
                Button(role: .destructive) {
                    engine.stopSession()
                } label: {
                    Label("Arrêter et voir le rapport", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if let message = engine.message {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
        case .idle:
            EmptyView()
        }
    }

    private var pitchBlock: some View {
        HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(engine.pitchText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                Text(engine.pitchDetail)
                    .font(.callout)
                    .foregroundStyle(engine.pitchColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: engine.rms)
                    .tint(engine.rms > 0.6 ? .orange : .green)
                    .frame(width: 140)
                Text("Niveau micro").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Panneau « position en direct » (à droite)

    private var livePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(engine.analysisMode == .bow ? "Archet en direct" : "Position en direct")
                    .font(.headline)
                Spacer()
                Button {
                    showLivePanel = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            if engine.analysisMode == .bow {
                if let feedback = engine.bowFeedback {
                    bowLiveCard(feedback)
                } else {
                    Text(engine.bowAlert ?? "Archet non détecté — cadrez de profil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if engine.livePosture.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("En attente de détection…").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ForEach(engine.livePosture) { status in
                    liveRuleRow(status)
                }
            }

            if let feedback = engine.lastNoteFeedback {
                lastNoteCard(feedback)
            }

            Text("Une erreur devient une alerte après 5 s persistantes · 2 alertes max · 20 s de repos entre deux alertes.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 290)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }

    private func liveRuleRow(_ status: LiveRuleStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.violated ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(status.violated ? .orange : .green)
                Text(status.title).font(.callout.weight(.semibold))
                Spacer()
                Text(status.violated ? "à corriger" : "OK")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(status.violated ? .orange : .green)
            }
            ProgressView(value: min(status.severity, 1))
                .tint(status.violated ? .orange : .green)
            if status.violated {
                Text(status.correction)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func bowLiveCard(_ feedback: BowEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
    }

    private func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
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
