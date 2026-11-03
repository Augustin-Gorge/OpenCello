import SwiftUI
import AppKit

/// Page Rapports : historique complet des séances à gauche, rapport détaillé
/// (stats, commentaires, exercices) dans l'app à droite.
struct ReportsView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var selectedID: UUID?

    private var selectedRecord: SessionRecord? {
        engine.progress.records.first { $0.id == selectedID } ?? engine.progress.records.first
    }

    var body: some View {
        HSplitView {
            historyPane
                .frame(minWidth: 270, idealWidth: 310, maxWidth: 400)
            detailPane
                .frame(minWidth: 560, maxWidth: .infinity)
        }
        .onAppear(perform: syncSelectionFromEngine)
        .onChange(of: engine.selectedReportID) { _, _ in
            syncSelectionFromEngine()
        }
    }

    private func syncSelectionFromEngine() {
        if let id = engine.selectedReportID, engine.progress.records.contains(where: { $0.id == id }) {
            selectedID = id
            engine.selectedReportID = nil
        } else if selectedID == nil {
            selectedID = engine.progress.records.first?.id
        }
    }

    // MARK: - Historique

    private var historyPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Historique").font(.title3.bold())
                Spacer()
                Text("\(engine.progress.records.count) rapport(s)")
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
                    historyRow(record)
                        .tag(record.id)
                }
            }
        }
    }

    private func historyRow(_ record: SessionRecord) -> some View {
        let score = SessionScore.compute(for: record)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(record.title).font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                if score.total > 0 {
                    Text("\(score.total)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(score.tierColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(score.tierColor.opacity(0.14)))
                }
            }
            Text("\(record.mode) · \(formattedDate(record.date))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(record.duration / 60)) min · \(Int(record.inTuneRatio * 100)) % justes · \(Int(record.totalPostureSeconds)) s en alerte")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Détail

    @ViewBuilder
    private var detailPane: some View {
        if let record = selectedRecord {
            ReportView(record: record)
        } else {
            ContentUnavailableView(
                "Aucun rapport",
                systemImage: "chart.xyaxis.line",
                description: Text("Les séances terminées apparaîtront ici avec leurs statistiques, commentaires et exercices.")
            )
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}
