import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PieceView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var showImporter = false
    @State private var showPDFImporter = false
    @State private var showStudio = false

    var body: some View {
        HSplitView {
            searchPane
                .frame(minWidth: 380, idealWidth: 440, maxWidth: 520)
            followPane
                .frame(minWidth: 420, maxWidth: .infinity)
        }
        .sheet(item: $engine.liveReplay) { moment in
            ReplayView(moment: moment)
        }
        .sheet(isPresented: $showStudio) {
            if let url = engine.scoreURL {
                ScoreStudioView(url: url) { parsed in
                    engine.applyEditedScore(parsed)
                }
            } else {
                ContentUnavailableView(
                    "Aucune partition",
                    systemImage: "music.note.list",
                    description: Text("Chargez ou convertissez d'abord un MusicXML.")
                )
                .frame(width: 520, height: 220)
            }
        }
    }

    // MARK: - Recherche IMSLP + import

    private var searchPane: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chercher une œuvre sur IMSLP").font(.headline)
            HStack {
                TextField("Ex. : Allegro appassionato Saint-Saëns", text: $engine.imslpQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { engine.searchIMSLP() }
                Button("Rechercher") { engine.searchIMSLP() }
                    .disabled(engine.imslpLoading)
            }

            if engine.imslpLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Recherche…").font(.caption)
                }
            }

            if let composer = engine.imslpComposer {
                HStack(spacing: 6) {
                    Text("Compositeur détecté : \(composer)")
                    if engine.imslpUsedFallback {
                        Text("· recherche élargie")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let error = engine.imslpError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if !engine.imslpLoading, engine.imslpResults.isEmpty, engine.imslpError == nil {
                Text("Astuce : tapez le compositeur et un mot du titre, même sans accents ni orthographe exacte (« allegro appasionato saint saens »).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !engine.imslpResults.isEmpty {
                Text("\(engine.imslpResults.count) résultat(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.imslpResults) { work in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(work.title).font(.callout.weight(.semibold))
                                if !work.cleanSnippet.isEmpty {
                                    Text(work.cleanSnippet)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 12) {
                                    Button("Ouvrir sur IMSLP") { engine.openIMSLPPage(for: work) }
                                        .buttonStyle(.link)
                                    Button("Utiliser ce titre") { engine.selectIMSLPTitle(work) }
                                        .buttonStyle(.link)
                                    if engine.scoreTitle == work.title {
                                        Label("retenu", systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            if let workTitle = engine.imslpWorkTitle {
                Divider()
                Text("Fichiers PDF de l'œuvre").font(.headline)
                Text(workTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if engine.imslpFilesLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Chargement des fichiers…").font(.caption)
                    }
                }
                if let error = engine.imslpFilesError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                if !engine.imslpFiles.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(engine.imslpFiles) { file in
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                            .font(.caption.weight(.semibold))
                                        if !file.description.isEmpty {
                                            Text(file.description)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Text(file.isPublicDomain
                                             ? "Domaine public"
                                             : (file.copyright.isEmpty
                                                ? "Licence non précisée"
                                                : file.copyright))
                                            .font(.caption2)
                                            .foregroundStyle(file.isPublicDomain ? .green : .orange)
                                    }
                                    Spacer()
                                    if engine.imslpDownloadingIndex == file.index {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Button {
                                            engine.downloadIMSLPFile(file)
                                        } label: {
                                            Image(systemName: "arrow.down.circle")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Télécharger ce PDF")
                                        .disabled(file.index == nil
                                                  || engine.imslpDownloadingIndex != nil)
                                    }
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                } else if !engine.imslpFilesLoading, engine.imslpFilesError == nil {
                    Text("Aucun PDF listé sur cette page.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Partition pour le suivi").font(.headline)
            Text("IMSLP fournit des PDF. OpenCello peut les convertir en MusicXML avec Audiveris (outil externe), puis les modifier dans MuseScore. Vous pouvez aussi importer un MusicXML déjà prêt.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    showImporter = true
                } label: {
                    Label("Importer MusicXML…", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    showPDFImporter = true
                } label: {
                    Label("Importer un PDF…", systemImage: "doc.richtext")
                }
                .buttonStyle(.bordered)

                Button("Gamme de démo") { engine.loadDemoScore() }
                    .buttonStyle(.bordered)
            }

            if let pdf = engine.currentPDF {
                VStack(alignment: .leading, spacing: 8) {
                    Label(pdf.lastPathComponent, systemImage: "doc.richtext")
                        .font(.callout.weight(.semibold))

                    if let xml = engine.currentMusicXML {
                        Text("MusicXML : \(xml.lastPathComponent)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                if engine.scoreURL != xml {
                                    engine.importScore(from: xml)
                                }
                                showStudio = true
                            } label: {
                                Label("Voir / modifier la partition", systemImage: "eye")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(engine.omrState.isRunning)

                            Menu {
                                Button("Reconvertir avec Audiveris") {
                                    engine.convertCurrentPDF(force: true)
                                }
                                Button("Afficher dans le Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([xml])
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 28)
                        }
                    } else {
                        Button {
                            engine.convertCurrentPDF()
                        } label: {
                            Label("Convertir en MusicXML", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(engine.omrState.isRunning)
                    }

                    if engine.omrState.isRunning {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(engine.omrState.label)
                                .font(.caption)
                            Button("Annuler") { engine.cancelOMR() }
                                .buttonStyle(.link)
                        }
                    }
                    if case let .failed(message) = engine.omrState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            if let message = engine.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.xml, UTType(filenameExtension: "musicxml") ?? .xml],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                engine.importScore(from: url)
            }
        }
        .fileImporter(
            isPresented: $showPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                engine.importPDF(from: url)
            }
        }
        }
    }

    // MARK: - Suivi

    private var followPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let score = engine.score {
                Text(engine.scoreTitle.isEmpty ? score.title : engine.scoreTitle).font(.title2.bold())
                if let composer = score.composer, !composer.isEmpty {
                    Text(composer).font(.caption).foregroundStyle(.secondary)
                }

                if let xml = engine.currentMusicXML {
                    HStack(spacing: 8) {
                        Button {
                            showStudio = true
                        } label: {
                            Label("Voir / modifier", systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                        .disabled(engine.pieceRunning)
                        .help(engine.pieceRunning
                              ? "Arrêtez le suivi pour modifier la partition."
                              : "Aperçu intégré + édition dans MuseScore")
                        Text(xml.lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Picker("Partie", selection: $engine.selectedPartIndex) {
                        ForEach(Array(score.parts.enumerated()), id: \.offset) { index, part in
                            Text(part.name.isEmpty ? "Partie \(index + 1)" : part.name).tag(index)
                        }
                    }
                    .frame(maxWidth: 280)
                    .disabled(engine.pieceRunning)

                    Spacer()
                    Text("\(currentPartNotes) notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tempo de référence").font(.callout)
                    TextField("BPM", value: $engine.pieceBPM, format: .number)
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                        .disabled(engine.pieceRunning)
                    Text("BPM").font(.caption).foregroundStyle(.secondary)
                    Spacer()

                    if engine.pieceRunning {
                        Button(role: .destructive) {
                            engine.stopPieceSession()
                        } label: {
                            Label("Arrêter", systemImage: "stop.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            engine.startPieceSession()
                        } label: {
                            Label("Démarrer le suivi", systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if engine.pieceRunning {
                    feedbackPanel
                } else {
                    Text("Choisissez la partie violoncelle, réglez le tempo, puis jouez : OpenCello suit votre position et signale justesse et rythme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let stats = engine.pieceStats {
                    statsPanel(stats)
                }

                if engine.pieceStats != nil, !engine.pieceRunning {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Dernier rapport enregistré — consultez l'onglet Rapports.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 14) {
                    ContentUnavailableView(
                        "Aucune partition chargée",
                        systemImage: "music.note.list",
                        description: Text("Cherchez une œuvre sur IMSLP, importez un MusicXML ou chargez la gamme de démonstration.")
                    )

                    if !engine.scoreTitle.isEmpty {
                        VStack(spacing: 6) {
                            Text("Œuvre sélectionnée").font(.caption).foregroundStyle(.secondary)
                            Text(engine.scoreTitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            HStack {
                                Button {
                                    showImporter = true
                                } label: {
                                    Label("Importer le MusicXML…", systemImage: "doc.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                Button {
                                    showPDFImporter = true
                                } label: {
                                    Label("Importer un PDF…", systemImage: "doc.richtext")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .padding(16)
    }

    private var currentPartNotes: Int {
        guard let score = engine.score, score.parts.indices.contains(engine.selectedPartIndex) else {
            return 0
        }
        return score.parts[engine.selectedPartIndex].notes.count
    }

    private var feedbackPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let feedback = engine.pieceFeedback, feedback.matched {
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("Attendu").font(.caption2).foregroundStyle(.secondary)
                        Text(feedback.expectedName)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                    }
                    VStack(alignment: .leading) {
                        Text("Entendu").font(.caption2).foregroundStyle(.secondary)
                        Text(feedback.detectedName)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                    }
                    VStack(alignment: .leading) {
                        Text("Justesse").font(.caption2).foregroundStyle(.secondary)
                        Text(feedback.cents.map { String(format: "%+.0f c", $0) } ?? "—")
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(feedback.isInTune ? .green : .red)
                    }
                    VStack(alignment: .leading) {
                        Text("Rythme").font(.caption2).foregroundStyle(.secondary)
                        Text(feedback.rhythmMs.map { String(format: "%+.0f ms", $0) } ?? "—")
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(feedback.isOnTime ? .green : .orange)
                    }
                }

                Text("Mesure \(feedback.measure ?? 0) · \(Int(engine.pieceProgress * 100)) %")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: engine.pieceProgress)
                positionRow
                Text(feedback.message).font(.callout)
            } else if let feedback = engine.pieceFeedback {
                Text(feedback.message).font(.callout).foregroundStyle(.orange)
                ProgressView(value: engine.pieceProgress)
            } else {
                Text("En attente de la première note…").font(.callout).foregroundStyle(.secondary)
            }
            if engine.pieceRunning {
                HStack(alignment: .top, spacing: 10) {
                    CameraPreview(camera: engine.camera, landmarks: engine.overlayLandmarks)
                        .frame(width: 220, height: 124)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    Text("Cadre la main gauche et la touche pour la position/le doigté. La caméra reste locale ; aucune vidéo n'est enregistrée.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    /// Position + doigt estimés (P14 + audio), avec la confiance affichée et
    /// l'accès au replay du dernier moment apparié.
    private var positionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                if let assignment = engine.pieceAssignment {
                    Label(assignment.positionText, systemImage: "hand.point.up.left")
                    Text(assignment.fingerText)
                    Text(assignment.exact ? "exacte" : "estimée")
                        .foregroundStyle(assignment.exact ? Color.green : Color.secondary)
                    Text("\(Int((assignment.confidence * 100).rounded())) %")
                        .foregroundStyle(.secondary)
                    if assignment.isShift, let from = assignment.fromPosition {
                        Text("depuis \(from)e")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Position et doigt : en attente de la première note")
                        .foregroundStyle(.secondary)
                }
                if let glide = engine.pieceGlideMs, glide >= 80 {
                    Text(String(format: "glissé %.0f ms", glide))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Revoir ça") { engine.replayLastMoment() }
                    .buttonStyle(.bordered)
                    .disabled(engine.pieceLastMoment == nil)
            }
            .font(.caption)
            if let assignment = engine.pieceAssignment, !assignment.exact, !assignment.alternatives.isEmpty {
                Text("Candidats : \(assignment.alternatives.joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if let assignment = engine.pieceAssignment {
                Text(assignment.source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(engine.pieceHandStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statsPanel(_ stats: PieceStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bilan en direct").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                metric("Notes", "\(stats.matched)/\(stats.totalNotes)")
                metric("Justes", "\(Int(stats.inTuneRatio * 100)) %")
                metric("Écart", String(format: "%.0f c", stats.meanAbsCents))
                metric("Rythme", String(format: "%.0f ms", stats.meanAbsRhythmMs))
                metric("Tempo", stats.estimatedTempo.map { String(format: "%.0f", $0) } ?? "—")
                metric("Hors part.", "\(stats.outOfScore)")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit())
        }
    }
}
