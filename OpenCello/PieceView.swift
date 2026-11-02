import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PieceView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var showImporter = false

    var body: some View {
        HSplitView {
            searchPane
                .frame(minWidth: 380, idealWidth: 440, maxWidth: 520)
            followPane
                .frame(minWidth: 420, maxWidth: .infinity)
        }
    }

    // MARK: - Recherche IMSLP + import

    private var searchPane: some View {
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
                .frame(maxHeight: 260)
            }

            Divider()

            Text("Partition pour le suivi").font(.headline)
            Text("IMSLP fournit des PDF. Pour suivre votre jeu note par note, importez un **MusicXML** (export MuseScore / Finale / Sibelius). Le PDF reste disponible sur IMSLP pour le travail.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    showImporter = true
                } label: {
                    Label("Importer MusicXML…", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button("Gamme de démo") { engine.loadDemoScore() }
                    .buttonStyle(.bordered)
            }

            if let message = engine.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.xml, UTType(filenameExtension: "musicxml") ?? .xml],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                engine.importScore(from: url)
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

                if !engine.reportMarkdown.isEmpty && !engine.pieceRunning {
                    Divider()
                    HStack {
                        Text("Rapport de la dernière séance « Morceau »").font(.caption.bold())
                        Spacer()
                        Button("Ouvrir") { engine.openReport() }
                            .disabled(engine.reportPath == nil)
                    }
                    ScrollView {
                        Text(engine.reportMarkdown)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
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
                            Button {
                                showImporter = true
                            } label: {
                                Label("Importer le MusicXML…", systemImage: "doc.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
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
                Text(feedback.message).font(.callout)
            } else if let feedback = engine.pieceFeedback {
                Text(feedback.message).font(.callout).foregroundStyle(.orange)
                ProgressView(value: engine.pieceProgress)
            } else {
                Text("En attente de la première note…").font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
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
