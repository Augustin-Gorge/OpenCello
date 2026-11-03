import SwiftUI
import AVFoundation
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var camera: CameraManager
    var onChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Réglages").font(.title2.bold())
                Spacer()
                Button("Fermer") { dismiss() }
            }

            Form {
                Picker("Profil", selection: $settings.profile) {
                    ForEach(SkillProfile.allCases) { profile in
                        VStack(alignment: .leading) {
                            Text(profile.title)
                            Text(profile.subtitle).font(.caption)
                        }
                        .tag(profile)
                    }
                }

                Picker("Diapason (La4)", selection: $settings.a4) {
                    Text("440 Hz").tag(440.0)
                    Text("441 Hz").tag(441.0)
                    Text("442 Hz").tag(442.0)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 8) {
                Text("Caméra").font(.headline)
                HStack {
                    Picker("Source", selection: Binding(
                        get: { camera.selectedCameraID ?? "" },
                        set: { camera.selectCamera($0.isEmpty ? nil : $0) }
                    )) {
                        Text("Automatique").tag("")
                        ForEach(camera.cameras) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .frame(maxWidth: 340)
                    Button("Rafraîchir") { camera.refreshCameras() }
                }
                Text("Pour la position exacte, choisis une caméra 3/4 avant-gauche (iPhone en caméra de continuité ou webcam externe), pas la webcam plein face.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Vidéo des séances").font(.headline)
                Toggle("Enregistrer la vidéo de chaque séance", isOn: $settings.recordSessionVideo)
                Text("Opt-in : la vidéo reste dans Movies/OpenCello/Sessions, sans audio ni envoi. Désactive-la pour ne rien enregistrer.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Ouvrir le dossier vidéos") {
                    try? FileManager.default.createDirectory(at: SessionVideoStore.directory, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(SessionVideoStore.directory)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tolérance de justesse : \(Int(settings.intonationTolerance)) cents")
                    .font(.callout)
                Slider(value: $settings.intonationTolerance, in: 10...50, step: 1)
                Text("Une note est considérée juste sous ce seuil.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tolérance de stabilité : \(Int(settings.stabilityTolerance)) cents")
                    .font(.callout)
                Slider(value: $settings.stabilityTolerance, in: 5...30, step: 1)
                Text("Écart-type maximal de la hauteur pendant une note tenue.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Autorisations").font(.headline)
                HStack {
                    Button("Autoriser la caméra") {
                        AVCaptureDevice.requestAccess(for: .video) { _ in }
                    }
                    Button("Autoriser le micro") {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    }
                    Button("Réglages Système") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text("OpenCello analyse tout en local : aucune vidéo ni audio n'est envoyée sur Internet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("OpenCello v1.1 — MVP local")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 600, height: 680)
        .onAppear { camera.refreshCameras() }
        .onChange(of: settings.profile) { _, _ in
            onChange()
        }
    }
}

struct OnboardingView: View {
    var onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bienvenue dans OpenCello").font(.title.bold())
            Text("Un coach de travail local pour le violoncelle : posture, son, rapports et exercices.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                onboardingRow("1", "Calibrez votre posture en 3 secondes, épaules basses.")
                onboardingRow("2", "Jouez : l'app suit la hauteur, la stabilité et les tensions posturales.")
                onboardingRow("3", "Arrêtez : un rapport détaillé propose des exercices ciblés.")
            }

            Divider()

            Text("Vie privée").font(.headline)
            Text("Caméra, micro et rapports restent sur ce Mac. Seule la recherche de partitions sur IMSLP utilise Internet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Autoriser la caméra") {
                    AVCaptureDevice.requestAccess(for: .video) { _ in }
                }
                Button("Autoriser le micro") {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }
                Spacer()
                Button("Commencer") {
                    onStart()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600, height: 420)
    }

    private func onboardingRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text).font(.callout)
        }
    }
}
