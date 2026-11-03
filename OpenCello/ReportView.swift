import SwiftUI
import Charts
import AppKit
import AVKit
import Liveline

/// Rapport de séance dans l'app, façon « page de statistiques de joueur » (HLTV) :
/// gros chiffres, graphiques Swift Charts, commentaires hiérarchisés et exercices ciblés.
/// Les rapports vivent dans l'app — plus aucun fichier Markdown généré.
struct ReportView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var exportMessage: String?
    @State private var replayMoment: ReplayMoment?
    @State private var videoToPlay: URL?
    let record: SessionRecord

    private var previous: SessionRecord? {
        guard let index = engine.progress.records.firstIndex(where: { $0.id == record.id }) else { return nil }
        return engine.progress.records.dropFirst(index + 1).first { $0.mode == record.mode }
    }

    private var commentary: ReportCommentary {
        ReportCommentary.build(for: record, previous: previous, settings: engine.settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                heroStats
                if record.noteCents.count > 1 {
                    intonationChart
                }
                if record.noteStability.count > 1 {
                    stabilityChart
                }
                if !record.posture.isEmpty {
                    postureChart
                }
                if record.noteCount > 0 {
                    noteDistributionCard
                }
                if let articulations = record.articulationCounts, !articulations.isEmpty {
                    articulationCard(articulations)
                }
                if let rate = record.meanVibratoRate, let extent = record.meanVibratoExtent {
                    vibratoCard(rate: rate, extent: extent)
                }
                analysisSection
                if !commentary.exercises.isEmpty {
                    exercisesSection
                }
                if let piece = record.piece {
                    pieceSection(piece)
                }
                if let hand = record.hand, hand.frames > 0 {
                    handSection(hand)
                }
                if let stats = record.positionStats, !stats.samples.isEmpty {
                    positionsSection(stats)
                }
                if let technique = record.technique {
                    techniqueSection(technique)
                }
                if let replays = record.replayMoments, !replays.isEmpty {
                    replaysSection(replays)
                }
                if let videoPath = record.videoPath,
                   FileManager.default.fileExists(atPath: videoPath) {
                    videoSection(videoPath)
                }
                if let bow = record.bow, bow.frames > 0 {
                    bowSection(bow)
                }
                exportsSection
            }
            .padding(20)
        }
        .sheet(item: $replayMoment) { moment in
            ReplayView(moment: moment)
        }
        .sheet(isPresented: Binding(
            get: { videoToPlay != nil },
            set: { if !$0 { videoToPlay = nil } }
        )) {
            if let url = videoToPlay {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Vidéo de la séance").font(.headline)
                        Spacer()
                        Button("Fermer") { videoToPlay = nil }
                    }
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(minWidth: 720, minHeight: 460)
                }
                .padding(16)
            }
        }
    }

    // MARK: - En-tête avec score

    private var header: some View {
        let score = commentary.score
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).font(.title.bold())
                Text("\(record.mode) · \(formattedDate(record.date)) · \(formattedDuration(record.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                componentBars(score)
                    .padding(.top, 4)
            }
            Spacer()
            VStack(spacing: 4) {
                Text("\(score.total)")
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(score.tierColor)
                Text(score.tierLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(score.tierColor)
                Text("Score / 100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(score.tierColor.opacity(0.12)))
        }
    }

    /// Décomposition du score en composantes (formule transparente).
    private func componentBars(_ score: SessionScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(score.components) { component in
                HStack(spacing: 8) {
                    Text(component.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    ProgressView(value: component.value, total: 100)
                        .tint(barColor(component.value))
                    Text(String(format: "%.0f", component.value))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .frame(width: 26, alignment: .trailing)
                }
            }
        }
    }

    private func barColor(_ value: Double) -> Color {
        value >= 75 ? .green : (value >= 50 ? .orange : .red)
    }

    // MARK: - Gros chiffres

    private var heroStats: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            heroStat("Score", "\(commentary.score.total)/100")
            if let piece = record.piece {
                heroStat("Notes reconnues", "\(piece.matched)/\(piece.total)")
                heroStat("Justesse moyenne", String(format: "%.0f cents", piece.meanAbsCents))
                heroStat("Rythme moyen", String(format: "%.0f ms", piece.meanAbsRhythmMs))
                heroStat("Hors partition", "\(piece.outOfScore)")
                heroStat("Tempo estimé", piece.estimatedTempo.map { String(format: "%.0f BPM", $0) } ?? "—")
            } else {
                heroStat("Notes analysées", "\(record.noteCount)")
                heroStat("Notes justes", record.noteCount > 0 ? "\(Int(record.inTuneRatio * 100)) %" : "—")
                heroStat("Écart moyen", record.noteCount > 0 ? String(format: "%.0f cents", record.meanAbsCents) : "—")
                heroStat("Stabilité", record.noteCount > 0 ? String(format: "%.0f cents", record.meanStability) : "—")
                heroStat("Temps sonore", String(format: "%.0f %%", record.soundingRatio * 100))
                heroStat("Temps en alerte", String(format: "%.0f s", record.totalPostureSeconds))
                if let hnr = record.meanHNR {
                    heroStat("HNR moyen", String(format: "%.0f dB", hnr))
                }
                if let rate = record.postureDetectionRate {
                    heroStat("Détection posture", "\(Int(rate * 100)) %")
                }
            }
        }
    }

    private func heroStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Graphiques (Swift Charts)

    private var intonationChart: some View {
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

    private var stabilityChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stabilité note par note").font(.headline)
            Text("Écart-type de hauteur pendant chaque note ; sous la ligne orange, la note est stable.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(Array(record.noteStability.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Note", index + 1),
                        y: .value("Cents", value)
                    )
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Note", index + 1),
                        y: .value("Cents", value)
                    )
                    .symbolSize(12)
                }
                RuleMark(y: .value("Tolérance", engine.settings.stabilityTolerance))
                    .foregroundStyle(.orange.opacity(0.4))
            }
            .frame(height: 160)
            .chartYAxisLabel("cents")
            .chartXAxisLabel("note")
        }
    }

    private var postureChart: some View {
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

    /// Répartition justesse de la séance en anneau (justes / approchantes / fausses).
    private var noteDistributionCard: some View {
        let buckets = NoteDistribution.buckets(for: record, tolerance: engine.settings.intonationTolerance)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Justesse — répartition des notes").font(.headline)
            if buckets.allSatisfy({ $0.count == 0 }) {
                Text("Pas de détail note par note pour cette séance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LivelineChart(
                    donut: buckets.map {
                        LivelineCategoryValue(id: $0.label, label: $0.label, value: Double($0.count))
                    },
                    color: .teal,
                    style: LivelineDonutStyle(
                        innerRadiusRatio: 0.55,
                        gapDegrees: 2,
                        colors: [.green, .orange, .red],
                        showsLabels: true,
                        showsValues: false
                    )
                )
                .frame(height: 190)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func articulationCard(_ articulations: [String: Int]) -> some View {
        let totals = articulations
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Articulations détectées").font(.headline)
            Text("Classification heuristique, indicative — non validée sur un jeu de référence.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Chart(totals) { item in
                BarMark(
                    x: .value("Occurrences", item.count),
                    y: .value("Articulation", item.name)
                )
                .cornerRadius(4)
                .foregroundStyle(Color.mint.gradient)
            }
            .frame(height: CGFloat(max(90, totals.count * 30)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func vibratoCard(rate: Double, extent: Double) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Taux de vibrato").font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "%.1f Hz", rate)).font(.title3.monospacedDigit().weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Amplitude moyenne").font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "±%.0f cents", extent / 2)).font(.title3.monospacedDigit().weight(.semibold))
            }
            Spacer()
            Text("Vibrato").font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Analyse (commentaires)

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Analyse").font(.title3.bold())

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.quote")
                    .foregroundStyle(.secondary)
                Text(commentary.global)
                    .font(.callout)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

            ForEach(commentary.posture) { item in
                commentaryCard(item)
            }
            ForEach(commentary.leftHand) { item in
                commentaryCard(item)
            }
            ForEach(commentary.positions) { item in
                commentaryCard(item)
            }
            ForEach(commentary.sound) { item in
                commentaryCard(item)
            }
            ForEach(commentary.techniques) { item in
                commentaryCard(item)
            }

            Text(commentary.confidence)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func commentaryCard(_ item: CommentaryItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.level.symbol)
                .foregroundStyle(item.level.color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title).font(.callout.weight(.semibold))
                    if let deltaText = item.deltaText, let improving = item.improving {
                        HStack(spacing: 3) {
                            Image(systemName: improving ? "arrow.down.right" : "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(deltaText)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(improving ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill((improving ? Color.green : Color.orange).opacity(0.12)))
                    }
                }
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.advice)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.level.color.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Exercices recommandés

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercices pour progresser").font(.title3.bold())
            ForEach(commentary.exercises) { exercise in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(exercise.id) — \(exercise.title)")
                            .font(.callout.weight(.semibold))
                        Text(exercise.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(exercise.category) · \(exercise.level) · \(exercise.durationMinutes) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Voir la fiche") {
                        engine.openExercise(exercise.id)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.7)))
            }
        }
    }

    // MARK: - Morceau et archet

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
    }

    // MARK: - Main gauche, positions, techniques, replays (v1.1)

    private func handSection(_ hand: HandRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Main gauche").font(.headline)
            if let rate = hand.detectionRate {
                Text("Main détectée sur \(Int(rate * 100)) % des frames · \(hand.validFrames) frames exploitables")
                    .font(.callout)
            }
            if let angle = hand.meanAngleDegrees {
                Text(String(format: "Angle main/avant-bras : %.0f° en moyenne (max %.0f°) · seuil du profil : %.0f°",
                            angle, hand.maxAngleDegrees ?? angle,
                            PostureRules.handThresholds(for: engine.settings.profile).handAngleLimit))
                    .font(.caption)
            }
            if let ratio = hand.thumbHypothesisRatio, ratio > 0 {
                Text(String(format: "Pouce probablement crispé sur %.0f %% des frames — hypothèse, pas une certitude (A18).", ratio * 100))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            ForEach(hand.rules.filter { $0.seconds > 1 || $0.occurrences > 0 }) { rule in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(rule.title).font(.caption.weight(.semibold))
                    if rule.confidence != nil && !rule.title.lowercased().contains("hypothèse") {
                        Text("hypothèse")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                    Spacer()
                    Text(String(format: "%.0f s · %d occurrence(s)", rule.seconds, rule.occurrences))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
    }

    private func positionsSection(_ stats: PositionStatsRecord) -> some View {
        let aggregates = PositionAnalysis.aggregates(from: stats.samples)
        let measured = stats.samples.filter { $0.position != nil }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("Positions et déplacements").font(.headline)
            HStack(spacing: 18) {
                reportMetric("Notes situées", "\(measured)/\(stats.samples.count)")
                reportMetric("Déplacements", "\(stats.shiftCount)")
                reportMetric("Arrivée moyenne", stats.meanArrivalCents.map { String(format: "%+.0f c", $0) } ?? "—")
                reportMetric("Durée de transition", stats.meanShiftDurationMs.map { String(format: "%.0f ms", $0) } ?? "—")
                reportMetric("Glissés parasites", "\(stats.parasiteGlides)")
            }
            if !aggregates.isEmpty {
                ForEach(aggregates.prefix(6)) { aggregate in
                    HStack(spacing: 8) {
                        Text(aggregate.label)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(String(format: "%d note(s) · écart %.0f c", aggregate.count, aggregate.meanAbsCents))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(aggregate.meanAbsCents > 30 ? Color.orange : Color.secondary)
                        if aggregate.glideCount > 0 {
                            Text(String(format: "glissé %.0f ms", aggregate.meanGlideMs ?? 0))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if let slope = aggregate.meanGlideSlope, abs(slope) >= 50 {
                            Text(String(format: "pente %.0f c/s", slope))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let ratio = aggregate.parasiteRatio, ratio > 0 {
                            Text(String(format: "parasites %.0f %%", ratio * 100))
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            Text("Position estimée par fusion audio + caméra (P14), résolution ±1 position ; la confiance est affichée note par note dans l'onglet Morceau.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
    }

    private func techniqueSection(_ technique: TechniqueRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Techniques particulières").font(.headline)
            if technique.piqueNotes > 0 {
                Text("Piqué : \(technique.piqueNotes) notes · \(technique.piqueUnevenRuns) série(s) inégale(s)")
                    .font(.callout)
                if let regularity = technique.piqueRegularity {
                    Text(String(format: "Régularité des durées : %.0f %% (seuil pédagogique : écart-type < 12 %%)", regularity * 100))
                        .font(.caption)
                        .foregroundStyle(regularity > 0.5 ? Color.secondary : Color.orange)
                }
                if let index = technique.piqueWorstIndex, let deviation = technique.piqueWorstDeviation {
                    Text(String(format: "La %de note de la série dévie de %.0f %% de la durée moyenne.", index, abs(deviation) * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if technique.glideShifts > 0 {
                Text(String(format: "Glissés : %d déplacement(s) avec portamento · %.0f ms en moyenne · pente %.0f cents/s",
                            technique.glideShifts, technique.meanGlideMs ?? 0, technique.meanGlideSlope ?? 0))
                    .font(.callout)
                Text("\(technique.voluntaryGlides) volontaire(s) (glissando écrit) · \(technique.parasiteGlides) parasite(s)")
                    .font(.caption)
                    .foregroundStyle(technique.parasiteGlides > 0 ? Color.orange : Color.secondary)
            }
            if technique.piqueNotes == 0 && technique.glideShifts == 0 {
                Text("Aucune technique particulière détectée sur cette séance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
    }

    private func replaysSection(_ moments: [ReplayMoment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Replays pédagogiques").font(.headline)
            Text("Chaque moment est reconstruit depuis les statistiques (aucun audio brut conservé) et peut être écouté en version jouée ou corrigée.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(moments) { moment in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(moment.title).font(.callout.weight(.semibold))
                        Text(moment.detail).font(.caption).foregroundStyle(.secondary)
                        Text(moment.advice).font(.caption2).foregroundStyle(.primary.opacity(0.8))
                    }
                    Spacer()
                    Button("Revoir ça") { replayMoment = moment }
                        .buttonStyle(.bordered)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.7)))
            }
        }
    }

    private func reportMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.callout.monospacedDigit().weight(.semibold))
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func videoSection(_ path: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vidéo de la séance").font(.headline)
            Text(URL(fileURLWithPath: path).lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    videoToPlay = URL(fileURLWithPath: path)
                } label: {
                    Label("Lire dans l'app", systemImage: "play.rectangle")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                } label: {
                    Label("Ouvrir dans le lecteur", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
            }
            Text("Enregistrement local opt-in — aucune vidéo n'est envoyée.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
    }

    private func bowSection(_ bow: BowRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Archet (profil)").font(.headline)
            Text("Angle conforme : \(Int(Double(bow.goodAngle) / Double(bow.frames) * 100)) % · zone conforme : \(Int(Double(bow.goodZone) / Double(bow.frames) * 100)) %")
                .font(.callout)
            if let contact = bow.meanContact {
                Text(String(format: "Contact moyen : %.0f %% · touche %.0f %% · milieu %.0f %% · chevalet %.0f %%",
                            contact * 100,
                            (bow.tastoRatio ?? 0) * 100,
                            (bow.middleRatio ?? 0) * 100,
                            (bow.ponticelloRatio ?? 0) * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let speed = bow.meanSpeed {
                Text(String(format: "Vitesse moyenne %.2f · %d changement(s) de direction · angle moyen %.0f°",
                            speed, bow.directionChanges ?? 0, bow.meanAngleDeviation ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let contact = bow.meanContact, contact < 0.33 {
                Text("Tu joues majoritairement sur la touche : avance le point de contact vers le milieu puis le chevalet, en gardant le même angle.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("\(bow.frames) frames analysés · seuils : ±10° et zone 10-90 %")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
    }

    // MARK: - Exports

    private var exportsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Partager").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    if let url = ReportExporter.exportPDF(record) {
                        exportMessage = "PDF exporté : \(url.path)"
                        NSWorkspace.shared.open(url)
                    } else {
                        exportMessage = "Échec de l'export PDF."
                    }
                } label: {
                    Label("PDF", systemImage: "doc.richtext")
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
                    Label("JSON", systemImage: "curlybraces")
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

                Button {
                    ReportExporter.openFolder()
                } label: {
                    Label("Ouvrir le dossier", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            if let exportMessage {
                Text(exportMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Les rapports vivent dans l'app ; les exports restent disponibles pour votre professeur. Généré localement — aucune donnée n'a quitté ce Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatage

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
