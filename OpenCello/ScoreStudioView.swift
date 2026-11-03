import SwiftUI
import SheetMusic
import SheetMusicCore
import SheetMusicLayout
import SheetMusicUI

/// Aperçu intégré d'une partition MusicXML + édition dans **MuseScore**.
///
/// L'édition n'est pas réimplémentée ici : MuseScore est l'éditeur open
/// source de référence (GPL-3.0, outil externe jamais empaqueté). Le MusicXML
/// est converti en `.mscz` pour l'édition, puis reconverti automatiquement à
/// chaque enregistrement (⌘S) pour rafraîchir l'aperçu et le suivi.
struct ScoreStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ScoreStudioModel

    private let onReloaded: (Score) -> Void

    init(url: URL, onReloaded: @escaping (Score) -> Void = { _ in }) {
        _model = StateObject(wrappedValue: ScoreStudioModel(url: url))
        self.onReloaded = onReloaded
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                viewer
                Divider()
                sidebar
                    .frame(width: 300)
            }
        }
        .frame(minWidth: 1_000, minHeight: 700)
        .task {
            model.onReloaded = onReloaded
            model.start()
        }
        .onDisappear {
            model.flushPendingSync()
            model.stopWatching()
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.url.lastPathComponent)
                    .font(.headline)
                Text(model.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if model.isBusy {
                ProgressView().controlSize(.small)
            }
            if let status = model.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Recharger le MusicXML depuis le disque")
            .disabled(model.isLoading)

            if model.isMuseScoreAvailable {
                Button {
                    model.openInMuseScore()
                } label: {
                    Label("Modifier dans MuseScore", systemImage: "pencil.and.outline")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .help("Modifier dans MuseScore (⇧⌘E)")
                .disabled(model.isBusy)
            } else {
                Button {
                    model.installMuseScore()
                } label: {
                    Label("Installer MuseScore", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Fermer") {
                model.flushPendingSync()
                model.stopWatching()
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Aperçu

    @ViewBuilder
    private var viewer: some View {
        if model.isLoading {
            ProgressView("Ouverture de la partition…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.score == nil {
            ContentUnavailableView {
                Label("Aperçu indisponible", systemImage: "music.note.list")
            } description: {
                Text(model.errorMessage ?? "Le MusicXML n'a pas pu être lu.")
            } actions: {
                Button("Réessayer") { model.load() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if #available(macOS 15.0, *) {
            ScoreCanvas15(model: model)
        } else {
            ContentUnavailableView {
                Label("Aperçu intégré requis macOS 15", systemImage: "macwindow")
            } description: {
                Text("Sur macOS 14, utilisez MuseScore pour voir et modifier la partition. "
                     + "Le MusicXML reste synchronisé automatiquement.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Panneau latéral

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                editorCard
                syncCard
                fileCard
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("MuseScore (GPL-3.0) est un outil externe, jamais distribué "
                     + "avec OpenCello. L'aperçu utilise swift-sheet-music (MIT).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private var editorCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let version = model.museScoreVersion {
                    Label("MuseScore \(version) détecté", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    Text("Toutes les fonctions d'édition sont celles de MuseScore : "
                         + "notes, accords, liaisons, nuances, articulations, doigtés, "
                         + "mise en page, lecture.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        model.openInMuseScore()
                    } label: {
                        Label("Modifier dans MuseScore", systemImage: "pencil.and.outline")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)
                } else {
                    Label("MuseScore non installé", systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text("MuseScore est l'éditeur de partition open source de référence. "
                         + "Installez-le pour modifier cette partition sans perdre aucune "
                         + "fonction (nuances, doigtés, articulations…).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        model.installMuseScore()
                    } label: {
                        Label("Télécharger MuseScore", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("J'ai installé MuseScore — détecter") {
                        model.detectMuseScore()
                    }
                    .buttonStyle(.link)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Édition", systemImage: "pencil")
        }
    }

    private var syncCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Le MusicXML est converti en `.mscz` pour MuseScore, puis "
                     + "reconverti automatiquement après chaque ⌘S. L'aperçu et "
                     + "le suivi utilisent le MusicXML à jour.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.isWatching {
                    Label("Surveillance active", systemImage: "eye")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if let lastSync = model.lastSync {
                    Text("Dernière synchronisation : \(lastSync.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    model.syncFromMuseScore()
                } label: {
                    Label("Récupérer les modifications maintenant", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!model.hasEditFile || !model.isMuseScoreAvailable || model.isBusy)

                Button {
                    model.reload()
                } label: {
                    Label("Recharger le MusicXML", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Synchronisation", systemImage: "arrow.triangle.2.circlepath")
        }
    }

    private var fileCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Mesures", value: "\(model.measureCount)")
                LabeledContent("Parties", value: "\(model.partCount)")
                LabeledContent("Édition", value: model.hasEditFile ? "MSCZ présent" : "MSCZ à créer")
                Button {
                    model.revealInFinder()
                } label: {
                    Label("Afficher dans le Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Fichier", systemImage: "doc")
        }
    }
}

// MARK: - Canevas de partition

@available(macOS 15.0, *)
private struct ScoreCanvas15: View {
    @ObservedObject var model: ScoreStudioModel
    @State private var document: LayoutDocument?

    private let options = ScoreViewOptions(
        staffSize: 22,
        systemGap: 34,
        wrapToViewWidth: true,
        includeTitleFrame: false,
        breakPolicy: .honor,
        breakIndicatorVisibility: .none,
        measureNumbers: .systemStart
    )

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView([.vertical]) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 1)
                            .id("top")
                        if let score = model.score, let document {
                            ScoreView(
                                document: document,
                                score: score,
                                options: options
                            )
                            .padding(24)
                        } else {
                            ProgressView("Mise en page…")
                                .frame(maxWidth: .infinity, minHeight: 300)
                        }
                    }
                }
                .defaultScrollAnchor(.top)
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear {
                    rebuild(width: geometry.size.width)
                    scrollToTop(scroll)
                }
                .onChange(of: geometry.size.width) { _, width in
                    rebuild(width: width)
                }
                .onChange(of: model.scoreVersion) { _, _ in
                    rebuild(width: geometry.size.width)
                    scrollToTop(scroll)
                }
            }
        }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("top", anchor: .top)
        // Le document peut être posé après le premier passage de layout :
        // on réaffirme l'ancrage une fois le contenu monté.
        DispatchQueue.main.async {
            proxy.scrollTo("top", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            proxy.scrollTo("top", anchor: .top)
        }
    }

    private func rebuild(width: CGFloat) {
        guard let score = model.score else {
            document = nil
            return
        }
        // L'initialiseur de ScoreView installe les métriques CoreText du
        // paquet ; LayoutEngine les exige (assert en DEBUG sinon).
        _ = ScoreView(score: score)
        document = LayoutEngine.layout(
            score: score,
            options: options,
            availableWidth: max(320, width - 48)
        )
    }
}
