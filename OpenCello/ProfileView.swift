import SwiftUI
import Charts
import AppKit
import Liveline

/// Page « Profil » : façon fiche de joueur (HLTV). Graphique en radar (spider),
/// anneau (donut), courbes de tendance, moyennes chiffrées — Swift Charts + Accelerate.
struct ProfileView: View {
    @EnvironmentObject private var engine: SessionEngine

    private var records: [SessionRecord] { engine.progress.records }
    private var summary: ProfileSummary { ProfileSummary.compute(records: records) }

    var body: some View {
        if records.isEmpty {
            ContentUnavailableView(
                "Pas encore de données",
                systemImage: "chart.xyaxis.line",
                description: Text("Terminez une séance libre ou un morceau pour voir vos moyennes, tendances et forme ici.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    radarRow
                    extraStats
                    if !records.compactMap(\.hand).isEmpty
                        || records.contains(where: { !($0.positionStats?.samples.isEmpty ?? true) })
                        || !records.compactMap(\.technique).isEmpty {
                        v11Stats
                    }
                    formChart
                    if summary.intonationSeries.count > 1 || summary.stabilitySeries.count > 1
                        || summary.hnrSeries.count > 1 || summary.bowSeries.count > 1 {
                        trendGrid
                    }
                    distributionRow
                    bestWorst
                }
                .padding(20)
            }
        }
    }

    // MARK: - En-tête profil

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal.opacity(0.85), .blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "music.note")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Mon profil").font(.title.bold())
                Text("\(engine.settings.profile.title) — \(engine.settings.profile.subtitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            profileChip("Séances", "\(summary.sessionCount)")
            profileChip("Temps de travail", formattedTotalDuration)
            profileChip("Série de jours", "\(summary.currentStreak)")
            if let average = summary.averageScore {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", average))
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    Text("Score moyen").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.teal.opacity(0.12)))
            }
        }
    }

    private func profileChip(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.callout.monospacedDigit().weight(.semibold))
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Radar + moyennes

    private var radarRow: some View {
        HStack(alignment: .top, spacing: 14) {
            radarCard
                .frame(width: 360)
            averagesGrid
        }
    }

    private var radarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profil de compétences").font(.headline)
            Text("Moyennes des \(summary.window) dernières séances, chaque axe ramené à 0-100.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if summary.radar.count >= 3 {
                LivelineChart(
                    radar: summary.radar.map {
                        LivelineRadarPoint(label: $0.name, value: $0.value)
                    },
                    color: .teal,
                    style: LivelineRadarStyle(
                        range: 0...100,
                        gridLevels: 4,
                        fillOpacity: 0.25,
                        lineWidth: 2,
                        pointSize: 4,
                        showsLabels: true
                    )
                )
                .frame(height: 260)
            } else {
                Text("Pas encore assez de données pour le radar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var averagesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Moyennes des \(summary.window) dernières séances").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                averageCard("Score moyen", summary.averageScore.map { String(format: "%.0f / 100", $0) } ?? "—", trend: trend(named: "Score moyen"))
                averageCard("Justesse (écart moyen)", summary.averageIntonation.map { String(format: "%.0f cents", $0) } ?? "—", trend: trend(named: "Justesse (écart moyen)"))
                averageCard("Stabilité moyenne", summary.averageStability.map { String(format: "%.0f cents", $0) } ?? "—", trend: trend(named: "Stabilité moyenne"))
                averageCard("Temps en alerte", summary.averageAlertRatio.map { String(format: "%.0f %%", $0 * 100) } ?? "—", trend: trend(named: "Temps en alerte"))
                averageCard("Temps sonore", summary.averageSoundingRatio.map { String(format: "%.0f %%", $0 * 100) } ?? "—", trend: trend(named: "Temps sonore"))
                averageCard("HNR (timbre)", summary.averageHNR.map { String(format: "%.0f dB", $0) } ?? "—", trend: nil)
                averageCard("Vibrato", summary.averageVibratoRate.map { String(format: "%.1f Hz · ±%.0f c", $0, (summary.averageVibratoExtent ?? 0) / 2) } ?? "—", trend: nil)
            }
            Text("Les flèches comparent à la moyenne des 5 séances précédentes ; un écart faible (cents, temps en alerte) est une amélioration.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func averageCard(_ title: String, _ value: String, trend: TrendMetric?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.monospacedDigit().weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let trend {
                trendBadge(trend)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.75)))
    }

    private func trend(named name: String) -> TrendMetric? {
        summary.trends.first { $0.name == name }
    }

    @ViewBuilder
    private func trendBadge(_ trend: TrendMetric) -> some View {
        if let improving = trend.improving {
            HStack(spacing: 4) {
                Image(systemName: improving ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                Text(trend.deltaText)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(improving ? .green : .orange)
        } else {
            Text(trend.deltaText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Totaux

    private var extraStats: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
            statTile("Notes jouées", "\(summary.totalNotes)", icon: "music.note.list", color: .blue)
            statTile("Durée moyenne", summary.averageDuration.map { formatMinutes($0) } ?? "—", icon: "clock", color: .purple)
            statTile("Notes / séance", summary.sessionCount > 0 ? "\(summary.totalNotes / summary.sessionCount)" : "—", icon: "number", color: .indigo)
            statTile(
                "Archet conforme (angle)",
                summary.bowAngleConformity.map { String(format: "%.0f %%", $0) } ?? "—",
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                color: .orange
            )
            statTile(
                "Archet conforme (zone)",
                summary.bowZoneConformity.map { String(format: "%.0f %%", $0) } ?? "—",
                icon: "rectangle.and.hand.point.up.left",
                color: .orange
            )
            statTile(
                "Vibrato moyen",
                summary.averageVibratoRate.map { String(format: "%.1f Hz", $0) } ?? "—",
                icon: "waveform.path",
                color: .pink
            )
        }
    }

    private func statTile(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.callout.monospacedDigit().weight(.bold))
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Main gauche et positions (v1.1)

    private var v11Stats: some View {
        let handRecords = records.compactMap(\.hand)
        let validHands = handRecords.filter { $0.validFrames > 0 }
        let meanAngle = StatsKit.mean(validHands.compactMap(\.meanAngleDegrees))
        let handSessions = handRecords.filter { ($0.detectionRate ?? 0) > 0.2 }.count
        let positionNotes = records.flatMap { $0.positionStats?.samples ?? [] }
        let measured = positionNotes.filter { $0.position != nil }
        let shifts = positionNotes.filter(\.isShift)
        let arrival = StatsKit.mean(shifts.compactMap(\.cents))
        let shiftDuration = StatsKit.mean(shifts.compactMap(\.glideMs))
        let techniques = records.compactMap(\.technique)
        let piqueNotes = techniques.map(\.piqueNotes).reduce(0, +)
        let regularity = StatsKit.mean(techniques.compactMap(\.piqueRegularity))
        let parasites = techniques.map(\.parasiteGlides).reduce(0, +)
        let voluntary = techniques.map(\.voluntaryGlides).reduce(0, +)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Main gauche et positions").font(.headline)
            Text("Cumul des séances avec caméra : angle de main (P11), position/doigt estimés (P14) et techniques (piqué, glissé).")
                .font(.caption2)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                statTile("Séances main gauche", "\(handSessions)", icon: "hand.raised", color: .teal)
                statTile("Angle main moyen", meanAngle.map { String(format: "%.0f°", $0) } ?? "—", icon: "angle", color: .teal)
                statTile("Notes situées", "\(measured.count)/\(positionNotes.count)", icon: "hand.point.up.left", color: .blue)
                statTile("Déplacements", "\(shifts.count)", icon: "arrow.left.arrow.right", color: .indigo)
                statTile("Arrivée moyenne", arrival.map { String(format: "%+.0f c", $0) } ?? "—", icon: "target", color: .orange)
                statTile("Transition moyenne", shiftDuration.map { String(format: "%.0f ms", $0) } ?? "—", icon: "timer", color: .purple)
                statTile("Piqué régulier", regularity.map { String(format: "%.0f %%", $0 * 100) } ?? "—", icon: "metronome", color: .pink)
                statTile("Glissés parasites", "\(parasites) / \(parasites + voluntary)", icon: "waveform.path.ecg", color: .red)
            }
            if piqueNotes > 0 {
                Text("\(piqueNotes) notes piquées analysées au total.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let aggregates = PositionAnalysis.aggregates(from: positionNotes)
            if !aggregates.isEmpty {
                Text("Déplacements par doigt et position").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(aggregates.prefix(6)) { aggregate in
                    HStack(spacing: 8) {
                        Text(aggregate.label).font(.caption)
                        Spacer()
                        Text(String(format: "%d note(s) · écart %.0f c%@%@", aggregate.count, aggregate.meanAbsCents,
                                    aggregate.meanGlideSlope.map { String(format: " · pente %.0f c/s", $0) } ?? "",
                                    aggregate.parasiteRatio.map { String(format: " · parasites %.0f %%", $0 * 100) } ?? ""))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(aggregate.meanAbsCents > 30 ? Color.orange : Color.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Forme récente

    private var formChart: some View {
        card("Forme récente", subtitle: "Score global de chaque séance (0-100, formule transparente détaillée dans les rapports).") {
            if summary.form.count > 1 {
                Chart {
                    ForEach(summary.form) { point in
                        AreaMark(
                            x: .value("Séance", point.date, unit: .day),
                            y: .value("Score", point.value ?? 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.teal.opacity(0.15))
                        LineMark(
                            x: .value("Séance", point.date, unit: .day),
                            y: .value("Score", point.value ?? 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.teal)
                        PointMark(
                            x: .value("Séance", point.date, unit: .day),
                            y: .value("Score", point.value ?? 0)
                        )
                        .foregroundStyle(.teal)
                    }
                    if let average = summary.averageScore {
                        RuleMark(y: .value("Moyenne", average))
                            .foregroundStyle(.orange.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .frame(height: 200)
                .chartXAxisLabel("date")
                .chartYAxisLabel("score")
                .chartYScale(domain: 0...100)
            } else {
                Text("Encore une séance pour dessiner la courbe de forme.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tendances

    private var trendGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 430), spacing: 12)], spacing: 12) {
            if summary.intonationSeries.count > 1 {
                metricTrendCard(
                    title: "Justesse — écart moyen par séance",
                    subtitle: "Plus bas = plus juste. Ligne orange : tolérance (\(Int(engine.settings.intonationTolerance)) cents).",
                    series: summary.intonationSeries,
                    rule: engine.settings.intonationTolerance,
                    color: .blue
                )
            }
            if summary.stabilitySeries.count > 1 {
                metricTrendCard(
                    title: "Stabilité — écart-type par séance",
                    subtitle: "Plus bas = notes plus stables.",
                    series: summary.stabilitySeries,
                    rule: engine.settings.stabilityTolerance,
                    color: .indigo
                )
            }
            if summary.hnrSeries.count > 1 {
                metricTrendCard(
                    title: "Timbre — HNR moyen par séance",
                    subtitle: "Plus haut = son plus propre (rapport harmonique/bruit).",
                    series: summary.hnrSeries,
                    rule: nil,
                    color: .purple
                )
            }
            if summary.bowSeries.count > 1 {
                metricTrendCard(
                    title: "Archet — angle conforme par séance",
                    subtitle: "% de frames dans ±10° de la perpendiculaire.",
                    series: summary.bowSeries,
                    rule: nil,
                    color: .orange
                )
            }
            if summary.alertSeries.count > 1 {
                metricTrendCard(
                    title: "Posture — % du temps en alerte",
                    subtitle: "Plus bas = posture plus proche de votre baseline.",
                    series: summary.alertSeries,
                    rule: nil,
                    color: .red
                )
            }
        }
    }

    private func metricTrendCard(
        title: String,
        subtitle: String,
        series: [SeriesPoint],
        rule: Double?,
        color: Color
    ) -> some View {
        card(title, subtitle: subtitle) {
            Chart {
                ForEach(series) { point in
                    LineMark(
                        x: .value("Séance", point.date, unit: .day),
                        y: .value("Valeur", point.value ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                    PointMark(
                        x: .value("Séance", point.date, unit: .day),
                        y: .value("Valeur", point.value ?? 0)
                    )
                    .foregroundStyle(color)
                }
                if let rule {
                    RuleMark(y: .value("Tolérance", rule))
                        .foregroundStyle(.orange.opacity(0.45))
                }
            }
            .frame(height: 150)
            .chartXAxisLabel("date")
        }
    }

    // MARK: - Répartitions (donut + barres)

    private var distributionRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 430), spacing: 12)], spacing: 12) {
            if !summary.postureTotals.isEmpty {
                postureDonut
            }
            if !summary.articulationTotals.isEmpty {
                articulationCard
            }
        }
    }

    private var postureDonut: some View {
        card("Posture — répartition du temps en alerte", subtitle: "Cumul sur toutes les séances, par repère.") {
            LivelineChart(
                donut: summary.postureTotals.map {
                    LivelineCategoryValue(id: $0.ruleID, label: $0.title, value: $0.seconds)
                },
                color: .teal,
                style: LivelineDonutStyle(
                    innerRadiusRatio: 0.55,
                    gapDegrees: 2,
                    showsLabels: true,
                    showsValues: false
                )
            )
            .frame(height: 210)
        }
    }

    private var articulationCard: some View {
        card("Articulations détectées", subtitle: "Cumul toutes séances (classification heuristique, indicative).") {
            Chart(summary.articulationTotals) { item in
                BarMark(
                    x: .value("Occurrences", item.count),
                    y: .value("Articulation", item.name)
                )
                .cornerRadius(4)
                .foregroundStyle(Color.mint.gradient)
            }
            .frame(height: 210)
        }
    }

    // MARK: - Meilleure / pire séance

    @ViewBuilder
    private var bestWorst: some View {
        if summary.best != nil || summary.worst != nil {
            HStack(spacing: 10) {
                if let best = summary.best {
                    sessionCard("Meilleure séance", record: best, color: .green)
                }
                if let worst = summary.worst, worst.id != summary.best?.id {
                    sessionCard("Séance à retravailler", record: worst, color: .orange)
                }
            }
        }
    }

    private func sessionCard(_ title: String, record: SessionRecord, color: Color) -> some View {
        let score = SessionScore.compute(for: record)
        return Button {
            engine.openReportInHistory(record.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                HStack {
                    Text(record.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Text("\(score.total)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(score.tierColor)
                }
                Text("\(formattedDate(record.date)) · \(formattedDuration(record.duration)) — ouvrir le rapport")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Habillage

    private func card<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var formattedTotalDuration: String {
        let minutes = Int(summary.totalDuration / 60)
        if minutes >= 60 {
            return "\(minutes / 60) h \(minutes % 60) min"
        }
        return "\(minutes) min"
    }

    private func formatMinutes(_ seconds: Double) -> String {
        let total = Int(seconds / 60)
        return total >= 60 ? "\(total / 60) h \(total % 60)" : "\(total) min"
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
