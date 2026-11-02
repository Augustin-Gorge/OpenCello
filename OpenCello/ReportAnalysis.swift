import Foundation
import SwiftUI

// MARK: - Score de séance (0-100)

/// Score transparent d'une séance, inspiré des pages de statistiques de joueurs (HLTV).
/// Chaque composante est bornée à 0-100 puis pondérée selon les données disponibles.
/// Formule documentée (critère « mesurable plutôt que vague » du PRINCIPE.md) :
///   - Justesse   : 100·exp(−écart moyen / 20)                      — poids 0,35
///   - Stabilité  : 100·exp(−stabilité moyenne / 12)                — poids 0,20
///   - Posture    : 100·(1 − temps en alerte / durée de séance)     — poids 0,25
///   - Continuité : % de temps sonore (séance libre) ou % de notes
///                  reconnues (morceau)                             — poids 0,20
/// Les poids sont renormalisés sur les composantes réellement mesurées.
struct SessionScore {
    let intonation: Double?
    let stability: Double?
    let posture: Double?
    let continuity: Double?
    let total: Int

    struct Component: Identifiable {
        let name: String
        let value: Double
        var id: String { name }
    }

    var components: [Component] {
        var list: [Component] = []
        if let intonation { list.append(Component(name: "Justesse", value: intonation)) }
        if let stability { list.append(Component(name: "Stabilité", value: stability)) }
        if let posture { list.append(Component(name: "Posture", value: posture)) }
        if let continuity { list.append(Component(name: "Continuité", value: continuity)) }
        return list
    }

    var tierLabel: String {
        switch total {
        case 85...: return "Excellent"
        case 70..<85: return "Bon"
        case 55..<70: return "Correct"
        case 40..<55: return "Difficile"
        default: return "À consolider"
        }
    }

    var tierColor: Color {
        switch total {
        case 85...: return .green
        case 70..<85: return .teal
        case 55..<70: return .orange
        case 40..<55: return .orange
        default: return .red
        }
    }

    static func compute(for record: SessionRecord) -> SessionScore {
        let intonation = record.noteCount > 0 ? 100 * exp(-record.meanAbsCents / 20) : nil
        let stability = record.noteCount > 0 ? 100 * exp(-record.meanStability / 12) : nil
        let duration = max(record.duration, 1)

        var postureScore: Double?
        if !record.posture.isEmpty {
            postureScore = 100 * max(0, 1 - record.totalPostureSeconds / duration)
        }

        var continuity: Double?
        if let piece = record.piece {
            if piece.total > 0 {
                continuity = 100 * Double(piece.matched) / Double(piece.total)
            }
        } else {
            continuity = 100 * min(1, record.soundingSeconds / duration)
        }

        let pairs: [(value: Double, weight: Double)] = [
            (intonation, 0.35),
            (stability, 0.20),
            (postureScore, 0.25),
            (continuity, 0.20)
        ].compactMap { item in
            item.0.map { (value: $0, weight: item.1) }
        }

        let total: Int
        if pairs.isEmpty {
            total = 0
        } else {
            let weighted = pairs.reduce(0) { $0 + $1.value * $1.weight }
            let weights = pairs.reduce(0) { $0 + $1.weight }
            total = Int((weighted / weights).rounded())
        }

        return SessionScore(
            intonation: intonation,
            stability: stability,
            posture: postureScore,
            continuity: continuity,
            total: total
        )
    }
}

// MARK: - Commentaires de rapport

/// Un commentaire structuré : quoi, combien, pourquoi, quoi faire, et l'évolution
/// par rapport à la séance précédente.
struct CommentaryItem: Identifiable {
    enum Level {
        case good
        case watch
        case alert

        var color: Color {
            switch self {
            case .good: return .green
            case .watch: return .orange
            case .alert: return .red
            }
        }

        var symbol: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .watch: return "exclamationmark.circle.fill"
            case .alert: return "xmark.octagon.fill"
            }
        }
    }

    let id: String
    let title: String
    let detail: String
    let advice: String
    let level: Level
    let deltaText: String?
    let improving: Bool?
}

/// Analyse textuelle d'un rapport : commentaire global, axes posture, son,
/// note de confiance et exercices ciblés.
struct ReportCommentary {
    let score: SessionScore
    let global: String
    let posture: [CommentaryItem]
    let sound: [CommentaryItem]
    let confidence: String
    let exercises: [Exercise]

    static func build(for record: SessionRecord, previous: SessionRecord?, settings: AppSettings) -> ReportCommentary {
        let score = SessionScore.compute(for: record)
        let posture = postureItems(for: record, previous: previous)
        let sound = soundItems(for: record, previous: previous, settings: settings)

        let ruleIDs: [String] = {
            var ids = postureTopRuleIDs(for: record, limit: 3)
            if record.noteCount > 0 {
                if record.meanAbsCents > settings.intonationTolerance { ids.append("B1") }
                if record.meanStability > settings.stabilityTolerance { ids.append("B2") }
                if let hnr = record.meanHNR, hnr < 18 { ids.append("B7") }
            }
            return ids
        }()
        let exercises = ExerciseCatalog.recommendations(for: ruleIDs)

        return ReportCommentary(
            score: score,
            global: globalComment(record: record, score: score, posture: posture, sound: sound),
            posture: posture,
            sound: sound,
            confidence: confidenceText(for: record),
            exercises: exercises
        )
    }

    // MARK: - Axes posture

    private static func postureTopRuleIDs(for record: SessionRecord, limit: Int) -> [String] {
        record.posture
            .sorted { $0.seconds > $1.seconds }
            .filter { $0.seconds > 2 }
            .prefix(limit)
            .map(\.ruleID)
    }

    private static func postureItems(for record: SessionRecord, previous: SessionRecord?) -> [CommentaryItem] {
        let duration = max(record.duration, 1)
        return record.posture
            .sorted { $0.seconds > $1.seconds }
            .filter { $0.seconds > 2 }
            .prefix(3)
            .map { item in
                let ratio = item.seconds / duration
                let level: CommentaryItem.Level = ratio > 0.10 ? .alert : .watch
                let delta = deltaSeconds(current: item.seconds, previousSeconds: previousSeconds(for: item.ruleID, in: previous))
                let exercise = ExerciseCatalog.recommendations(for: [item.ruleID], limit: 1).first
                return CommentaryItem(
                    id: "posture-\(item.ruleID)",
                    title: item.title,
                    detail: "\(item.occurrences) occurrence(s) · \(Int(item.seconds)) s en position à corriger (\(Int(ratio * 100)) % de la séance)",
                    advice: "\(PostureRules.correction(for: item.ruleID))\(exercise.map { " Exercice ciblé : \($0.id) — \($0.title)." } ?? "")",
                    level: level,
                    deltaText: delta?.text,
                    improving: delta?.improving
                )
            }
    }

    // MARK: - Axes son

    private static func soundItems(for record: SessionRecord, previous: SessionRecord?, settings: AppSettings) -> [CommentaryItem] {
        var items: [CommentaryItem] = []

        if record.noteCount > 0 {
            let intonationDelta = deltaCents(current: record.meanAbsCents, previous: previous?.meanAbsCents, previousHadNotes: (previous?.noteCount ?? 0) > 0)
            let intonationLevel: CommentaryItem.Level
            if record.meanAbsCents <= settings.intonationTolerance {
                intonationLevel = .good
            } else if record.meanAbsCents <= settings.intonationTolerance * 2 {
                intonationLevel = .watch
            } else {
                intonationLevel = .alert
            }
            let intonationExercise = ExerciseCatalog.recommendations(for: ["B1"], limit: 1).first
            items.append(CommentaryItem(
                id: "sound-B1",
                title: "Justesse",
                detail: "\(Int(record.inTuneRatio * 100)) % de notes justes (≤ \(Int(settings.intonationTolerance)) cents) · écart moyen \(String(format: "%.0f", record.meanAbsCents)) cents",
                advice: intonationExercise.map { "Travaillez lentement au bourdon : \($0.id) — \($0.title)." }
                    ?? "Travaillez lentement avec un bourdon et vérifiez chaque note à la corde à vide.",
                level: intonationLevel,
                deltaText: intonationDelta?.text,
                improving: intonationDelta?.improving
            ))

            let stabilityDelta = deltaCents(current: record.meanStability, previous: previous?.meanStability, previousHadNotes: (previous?.noteCount ?? 0) > 0)
            let stabilityLevel: CommentaryItem.Level
            if record.meanStability <= settings.stabilityTolerance {
                stabilityLevel = .good
            } else if record.meanStability <= settings.stabilityTolerance * 2 {
                stabilityLevel = .watch
            } else {
                stabilityLevel = .alert
            }
            let stabilityExercise = ExerciseCatalog.recommendations(for: ["B2"], limit: 1).first
            items.append(CommentaryItem(
                id: "sound-B2",
                title: "Stabilité de la hauteur",
                detail: "Stabilité moyenne \(String(format: "%.0f", record.meanStability)) cents (tolérance \(Int(settings.stabilityTolerance)) cents)",
                advice: stabilityExercise.map { "Sons filés lents en contrôlant la main gauche : \($0.id) — \($0.title)." }
                    ?? "Sons filés lents en contrôlant la pression et la vitesse d'archet.",
                level: stabilityLevel,
                deltaText: stabilityDelta?.text,
                improving: stabilityDelta?.improving
            ))
        }

        if let hnr = record.meanHNR {
            let level: CommentaryItem.Level = hnr >= 18 ? .good : (hnr >= 10 ? .watch : .alert)
            items.append(CommentaryItem(
                id: "sound-B7",
                title: "Qualité du timbre",
                detail: "HNR moyen \(String(format: "%.0f", hnr)) dB (plus haut = son plus propre)",
                advice: "Sons filés pleine arche (EX-01) et contact franc de l'archet près du chevalet pour un son riche.",
                level: level,
                deltaText: nil,
                improving: nil
            ))
        }

        return items
    }

    // MARK: - Commentaire global

    private static func globalComment(record: SessionRecord, score: SessionScore, posture: [CommentaryItem], sound: [CommentaryItem]) -> String {
        guard score.total > 0 else {
            return "Pas assez de signal analysé pour évaluer cette séance : vérifiez l'éclairage, l'angle de la caméra et la position du micro, puis relancez une séance."
        }

        let priority: String
        if let worst = posture.max(by: { ($0.level == .alert ? 1 : 0) < ($1.level == .alert ? 1 : 0) }) {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else if let worst = sound.filter({ $0.level == .alert }).first {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else {
            priority = "Aucun axe critique majeur cette fois-ci."
        }

        let closing = score.total >= 70
            ? "Continuez sur cette dynamique en variant les exercices."
            : "Travaillez cet axe quelques minutes par jour : les exercices proposés ci-dessous sont mesurés par l'app."

        return "Score \(score.total)/100 — \(score.tierLabel). \(priority) \(closing)"
    }

    // MARK: - Confiance des mesures

    private static func confidenceText(for record: SessionRecord) -> String {
        var parts: [String] = []
        if let rate = record.postureDetectionRate {
            parts.append("posture détectée sur \(Int(rate * 100)) % des frames")
        }
        if let pitchFrames = record.pitchFrames, pitchFrames > 0, let valid = record.validPitchFrames {
            parts.append("\(Int(Double(valid) / Double(pitchFrames) * 100)) % d'échantillons de hauteur valides")
        }
        let head = parts.isEmpty ? "Confiance des mesures : données limitées." : "Confiance des mesures : " + parts.joined(separator: " · ") + "."
        return "\(head) Éclairage, angle de caméra et bruit ambiant peuvent dégrader la détection. Signalez les faux positifs."
    }

    // MARK: - Deltas

    private struct Delta {
        let text: String
        let improving: Bool
    }

    private static func previousSeconds(for ruleID: String, in previous: SessionRecord?) -> Double? {
        previous?.posture.first { $0.ruleID == ruleID }?.seconds
    }

    private static func deltaSeconds(current: Double, previousSeconds: Double?) -> Delta? {
        guard let previousSeconds else { return nil }
        let diff = current - previousSeconds
        guard abs(diff) >= 1 else { return Delta(text: "stable vs séance précédente", improving: true) }
        let text = String(format: "%+.0f s vs séance précédente", diff)
        return Delta(text: text, improving: diff < 0)
    }

    private static func deltaCents(current: Double, previous: Double?, previousHadNotes: Bool) -> Delta? {
        guard let previous, previousHadNotes else { return nil }
        let diff = current - previous
        guard abs(diff) >= 0.5 else { return Delta(text: "stable vs séance précédente", improving: true) }
        let text = String(format: "%+.0f cents vs séance précédente", diff)
        return Delta(text: text, improving: diff < 0)
    }
}

// MARK: - Profil (moyennes et tendances)

struct SeriesPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double?
}

struct PostureAggregate: Identifiable {
    let ruleID: String
    let title: String
    let seconds: Double
    var id: String { ruleID }
}

struct TrendMetric: Identifiable {
    let name: String
    let current: Double?
    let previous: Double?
    let currentText: String
    let deltaText: String
    let improving: Bool?
    var id: String { name }
}

/// Résumé général du profil : moyennes des dernières séances, tendances,
/// forme récente, cumuls de posture, meilleure/pire séance.
struct ProfileSummary {
    let sessionCount: Int
    let totalDuration: TimeInterval
    let currentStreak: Int
    let window: Int
    let averageScore: Double?
    let averageIntonation: Double?
    let averageStability: Double?
    let averageAlertRatio: Double?
    let averageSoundingRatio: Double?
    let trends: [TrendMetric]
    let form: [SeriesPoint]
    let intonationSeries: [SeriesPoint]
    let stabilitySeries: [SeriesPoint]
    let alertSeries: [SeriesPoint]
    let postureTotals: [PostureAggregate]
    let best: SessionRecord?
    let worst: SessionRecord?

    static func compute(records: [SessionRecord], window: Int = 10) -> ProfileSummary {
        let chronological = records.sorted { $0.date < $1.date }
        let recent = Array(records.prefix(window))

        // Moyennes sur la fenêtre récente.
        let scores = recent.map { SessionScore.compute(for: $0) }.filter { $0.total > 0 }
        let averageScore = StatsKit.mean(scores.map { Double($0.total) })
        let averageIntonation = StatsKit.mean(recent.filter { $0.noteCount > 0 }.map(\.meanAbsCents))
        let averageStability = StatsKit.mean(recent.filter { $0.noteCount > 0 }.map(\.meanStability))
        let averageAlertRatio = StatsKit.mean(recent.filter { !$0.posture.isEmpty }.map(\.alertRatio))
        let averageSoundingRatio = StatsKit.mean(
            recent.filter { $0.mode == "Séance libre" && $0.duration > 0 }.map(\.soundingRatio)
        )

        // Tendances : fenêtre courante (5 séances) vs fenêtre précédente.
        let trends = trendMetrics(records: records)

        // Séries chronologiques (sans les séances où la métrique est absente).
        func series(_ value: (SessionRecord) -> Double?) -> [SeriesPoint] {
            chronological.compactMap { record in
                value(record).map { SeriesPoint(date: record.date, value: $0) }
            }
        }
        let form = series { record in
            let score = SessionScore.compute(for: record)
            return score.total > 0 ? Double(score.total) : nil
        }
        let intonationSeries = series { $0.noteCount > 0 ? $0.meanAbsCents : nil }
        let stabilitySeries = series { $0.noteCount > 0 ? $0.meanStability : nil }
        let alertSeries = series { record in
            record.posture.isEmpty ? nil : record.alertRatio * 100
        }

        // Cumul posture, toutes séances confondues.
        var totals: [String: PostureAggregate] = [:]
        for record in records {
            for item in record.posture {
                var aggregate = totals[item.ruleID] ?? PostureAggregate(ruleID: item.ruleID, title: item.title, seconds: 0)
                aggregate = PostureAggregate(ruleID: item.ruleID, title: item.title, seconds: aggregate.seconds + item.seconds)
                totals[item.ruleID] = aggregate
            }
        }
        let postureTotals = totals.values.sorted { $0.seconds > $1.seconds }

        // Meilleure / pire séance (parmi celles qui ont un score calculable).
        let scored = records.map { (record: $0, score: SessionScore.compute(for: $0).total) }
            .filter { $0.score > 0 }
        let best = scored.max { $0.score < $1.score }?.record
        let worst = scored.min { $0.score < $1.score }?.record

        return ProfileSummary(
            sessionCount: records.count,
            totalDuration: records.reduce(0) { $0 + $1.duration },
            currentStreak: currentStreak(records: records),
            window: min(window, records.count),
            averageScore: averageScore,
            averageIntonation: averageIntonation,
            averageStability: averageStability,
            averageAlertRatio: averageAlertRatio,
            averageSoundingRatio: averageSoundingRatio,
            trends: trends,
            form: form,
            intonationSeries: intonationSeries,
            stabilitySeries: stabilitySeries,
            alertSeries: alertSeries,
            postureTotals: postureTotals,
            best: best,
            worst: worst
        )
    }

    private static func trendMetrics(records: [SessionRecord]) -> [TrendMetric] {
        let current = Array(records.prefix(5))
        let previous = Array(records.dropFirst(5).prefix(5))

        func trend(
            name: String,
            value: (SessionRecord) -> Double?,
            unit: String,
            lowerIsBetter: Bool
        ) -> TrendMetric {
            let currentValue = StatsKit.mean(current.compactMap(value))
            let previousValue = StatsKit.mean(previous.compactMap(value))
            let currentText = currentValue.map { String(format: "%.0f %@", $0, unit) } ?? "—"
            let improving: Bool?
            let deltaText: String
            if let currentValue, let previousValue {
                let diff = currentValue - previousValue
                improving = lowerIsBetter ? diff < 0 : diff > 0
                let sign = diff >= 0 ? "+" : "−"
                deltaText = "\(sign)\(String(format: "%.0f %@", abs(diff), unit)) vs 5 séances précédentes"
            } else {
                improving = nil
                deltaText = "pas assez de données"
            }
            return TrendMetric(
                name: name,
                current: currentValue,
                previous: previousValue,
                currentText: currentText,
                deltaText: deltaText,
                improving: improving
            )
        }

        return [
            trend(name: "Score moyen", value: { record in
                let score = SessionScore.compute(for: record)
                return score.total > 0 ? Double(score.total) : nil
            }, unit: "/100", lowerIsBetter: false),
            trend(name: "Justesse (écart moyen)", value: { $0.noteCount > 0 ? $0.meanAbsCents : nil }, unit: "c", lowerIsBetter: true),
            trend(name: "Stabilité moyenne", value: { $0.noteCount > 0 ? $0.meanStability : nil }, unit: "c", lowerIsBetter: true),
            trend(name: "Temps en alerte", value: { $0.posture.isEmpty ? nil : $0.alertRatio * 100 }, unit: "%", lowerIsBetter: true),
            trend(name: "Temps sonore", value: { $0.mode == "Séance libre" && $0.duration > 0 ? $0.soundingRatio * 100 : nil }, unit: "%", lowerIsBetter: false)
        ]
    }

    /// Nombre de jours consécutifs avec au moins une séance (aujourd'hui ou hier inclus).
    private static func currentStreak(records: [SessionRecord]) -> Int {
        let calendar = Calendar.current
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }
}
