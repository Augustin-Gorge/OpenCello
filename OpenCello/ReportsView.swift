import SwiftUI
import Charts
import AppKit

struct ReportsView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var selectedID: UUID?
    @State private var exportMessage: String?

    private var selectedRecord: SessionRecord? {
        engine.progress.records.first { $0.id == selectedID } ?? engine.progress.records.first
    }

    var body: some View {
        HSplitView {
            historyPane
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            detailPane
                .frame(minWidth: 520, maxWidth: .infinity)
        }
        .onAppear {
            if selectedID == nil {
                selectedID = engine.progress.records.first?.id
            }
        }
    }

    private var historyPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Historique").font(.title3.bold())
                Spacer()
                Text("\(engine.progress.records.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if engine.progress.records.isEmpty {
                Text("Aucune séance enregistrée.\nLancez une séance libre ou un morceau.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                Spacer()
            } else {
                List(engine.progress.records, selection: $selectedID) { record in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.title).font(.callout.weight(.semibold)).lineLimit(1)
                        Text("\(record.mode) · \(formattedDate(record.date))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(record.duration / 60)) min · \(Int(record.inTuneRatio * 100)) % justes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                    .tag(record.id)
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let record = selectedRecord {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(record)
                    statsGrid(record)
                    if record.noteCents.count > 1 {
                        intonationChart(record)
                    }
                    if !record.posture.isEmpty {
                        postureChart(record)
                    }
                    if let piece = record.piece {
                        pieceSection(piece)
                    }
                    if let bow = record.bow, bow.frames > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Archet (profil)").font(.headline)
                            Text("Angle conforme : \(Int(Double(bow.goodAngle) / Double(bow.frames) * 100)) % · zone conforme : \(Int(Double(bow.goodZone) / Double(bow.frames) * 100)) %")
                                .font(.callout)
                            Text("\(bow.frames) frames analysés · seuils : ±10° et zone 10-90 %")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                        )
                    }
                    exportSection(record)
                }
                .padding(16)
            }
        } else {
            ContentUnavailableView(
                "Aucun rapport",
                systemImage: "chart.xyaxis.line",
                description: Text("Les séances terminées apparaîtront ici avec leurs graphiques et exports.")
            )
        }
    }

    private func header(_ record: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title).font(.title2.bold())
            Text("\(record.mode) · \(formattedDate(record.date)) · \(formattedDuration(record.duration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statsGrid(_ record: SessionRecord) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
            stat("Notes", "\(record.noteCount)")
            stat("Justes", "\(Int(record.inTuneRatio * 100)) %")
            stat("Écart moyen", String(format: "%.0f cents", record.meanAbsCents))
            stat("Stabilité", String(format: "%.0f cents", record.meanStability))
            stat("Temps sonore", String(format: "%.0f s", record.soundingSeconds))
            stat("Temps en alerte", String(format: "%.0f s", record.posture.reduce(0) { $0 + $1.seconds }))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit().weight(.semibold))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func intonationChart(_ record: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Justesse note par note").font(.headline)
            Text("Écart en cents par rapport à la note tempérée ; la zone orange est la tolérance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(Array(record.noteCents.enumerated()), id: \.offset) { index, cents in
                    LineMark(
                        x: .value("Note", index + 1),
                        y: .value("Cents", cents)
                    )
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Note", index + 1),
                        y: .value("Cents", cents)
                    )
                    .symbolSize(12)
                }
                RuleMark(y: .value("Juste", 0))
                    .foregroundStyle(.gray.opacity(0.6))
                RuleMark(y: .value("Tolérance", engine.settings.intonationTolerance))
                    .foregroundStyle(.orange.opacity(0.35))
                RuleMark(y: .value("Tolérance basse", -engine.settings.intonationTolerance))
                    .foregroundStyle(.orange.opacity(0.35))
            }
            .frame(height: 190)
            .chartYAxisLabel("cents")
            .chartXAxisLabel("note")
        }
    }

    private func postureChart(_ record: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Temps passé en alerte posture").font(.headline)
            Chart(record.posture) { item in
                BarMark(
                    x: .value("Secondes", item.seconds),
                    y: .value("Règle", item.title)
                )
                .foregroundStyle(Color.orange.gradient)
            }
            .frame(height: CGFloat(max(90, record.posture.count * 34)))
        }
    }

    private func pieceSection(_ piece: PieceRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Morceau").font(.headline)
            Text("\(piece.matched)/\(piece.total) notes reconnues · \(piece.inTune) justes · \(piece.outOfScore) hors partition")
                .font(.callout)
            Text(String(format: "Justesse moyenne : %.0f cents · rythme moyen : %.0f ms",
                        piece.meanAbsCents, piece.meanAbsRhythmMs))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
    }

    private func exportSection(_ record: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    if let url = ReportExporter.exportPDF(record) {
                        exportMessage = "PDF exporté : \(url.path)"
                        NSWorkspace.shared.open(url)
                    } else {
                        exportMessage = "Échec de l'export PDF."
                    }
                } label: {
                    Label("Exporter PDF", systemImage: "doc.richtext")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    if let url = ReportExporter.exportJSON(record) {
                        exportMessage = "JSON exporté : \(url.path)"
                        NSWorkspace.shared.open(url)
                    } else {
                        exportMessage = "Échec de l'export JSON."
                    }
                } label: {
                    Label("Exporter JSON", systemImage: "curlybraces")
                }
                .buttonStyle(.bordered)

                Button {
                    ReportExporter.openFolder()
                } label: {
                    Label("Ouvrir le dossier", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    if let url = ReportExporter.exportTeacherPack(record) {
                        exportMessage = "Pack professeur : \(url.path)"
                        NSWorkspace.shared.open(url)
                    } else {
                        exportMessage = "Échec du pack professeur."
                    }
                } label: {
                    Label("Pack professeur", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    if let url = ReportExporter.exportAnonymized(engine.progress.records) {
                        exportMessage = "Export étude anonymisé : \(url.path)"
                        NSWorkspace.shared.open(url)
                    } else {
                        exportMessage = "Échec de l'export anonymisé."
                    }
                } label: {
                    Label("Export étude", systemImage: "lock.doc")
                }
                .buttonStyle(.bordered)
            }
            if let exportMessage {
                Text(exportMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%d min %02d s", seconds / 60, seconds % 60)
    }
}
