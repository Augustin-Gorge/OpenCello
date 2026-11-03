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
    let leftHand: [CommentaryItem]
    let positions: [CommentaryItem]
    let techniques: [CommentaryItem]
    let confidence: String
    let exercises: [Exercise]

    static func build(for record: SessionRecord, previous: SessionRecord?, settings: AppSettings) -> ReportCommentary {
        let score = SessionScore.compute(for: record)
        let posture = postureItems(for: record, previous: previous)
        let sound = soundItems(for: record, previous: previous, settings: settings)
        let leftHand = handItems(for: record)
        let positions = positionItems(for: record)
        let techniques = techniqueItems(for: record)

        let ruleIDs: [String] = {
            var ids = postureTopRuleIDs(for: record, limit: 3)
            if record.noteCount > 0 {
                if record.meanAbsCents > settings.intonationTolerance { ids.append("B1") }
                if record.meanStability > settings.stabilityTolerance { ids.append("B2") }
                if let hnr = record.meanHNR, hnr < 18 { ids.append("B7") }
            }
            if let hand = record.hand {
                for rule in hand.rules where rule.seconds > 2 || rule.occurrences > 0 {
                    ids.append(rule.ruleID)
                }
            }
            if let technique = record.technique {
                if technique.piqueUnevenRuns > 0 { ids.append("B17") }
                if technique.parasiteGlides > 0 { ids.append("B14") }
            }
            if let stats = record.positionStats {
                if let arrival = stats.meanArrivalCents, abs(arrival) > 25 { ids.append("B15") }
                if let duration = stats.meanShiftDurationMs, duration > 180 { ids.append("B16") }
            }
            return ids
        }()
        let exercises = ExerciseCatalog.recommendations(for: ruleIDs)

        return ReportCommentary(
            score: score,
            global: globalComment(
                record: record,
                score: score,
                posture: posture,
                sound: sound,
                leftHand: leftHand,
                positions: positions,
                techniques: techniques
            ),
            posture: posture,
            sound: sound,
            leftHand: leftHand,
            positions: positions,
            techniques: techniques,
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

    // MARK: - Main gauche (A17-A20)

    private static func handItems(for record: SessionRecord) -> [CommentaryItem] {
        guard let hand = record.hand else { return [] }
        let duration = max(record.duration, 1)
        return hand.rules
            .filter { $0.seconds > 2 || $0.occurrences > 0 }
            .sorted { $0.seconds > $1.seconds }
            .prefix(3)
            .map { rule in
                let ratio = rule.seconds / duration
                let level: CommentaryItem.Level
                if rule.ruleID == "A18" {
                    level = .watch
                } else if ratio > 0.10 || rule.occurrences >= 3 {
                    level = .alert
                } else {
                    level = .watch
                }
                let exercise = ExerciseCatalog.recommendations(for: [rule.ruleID], limit: 1).first
                var detail: String
                switch rule.ruleID {
                case "A17":
                    detail = String(
                        format: "angle main/avant-bras moyen %.0f° (max %.0f°) · %d s au-delà du seuil",
                        hand.meanAngleDegrees ?? 0,
                        hand.maxAngleDegrees ?? 0,
                        Int(rule.seconds)
                    )
                case "A18":
                    detail = String(
                        format: "pouce probablement crispé sur %.0f %% des frames main — hypothèse, pas une certitude",
                        (hand.thumbHypothesisRatio ?? 0) * 100
                    )
                case "A19":
                    detail = String(
                        format: "vitesse des bouts de doigts élevée · %d s au-delà du seuil · souplesse indicative",
                        Int(rule.seconds)
                    )
                default:
                    detail = "\(rule.occurrences) déplacement(s) avec un coude qui ne guide pas assez la main"
                }
                return CommentaryItem(
                    id: "hand-\(rule.ruleID)",
                    title: rule.title,
                    detail: detail,
                    advice: "\(PostureRules.handCorrection(for: rule.ruleID))\(exercise.map { " Exercice ciblé : \($0.id) — \($0.title)." } ?? "")",
                    level: level,
                    deltaText: nil,
                    improving: nil
                )
            }
    }

    // MARK: - Positions et déplacements

    private static func positionItems(for record: SessionRecord) -> [CommentaryItem] {
        let notes = record.positionStats?.samples ?? []
        guard !notes.isEmpty else { return [] }
        var items: [CommentaryItem] = []

        if let worst = PositionAnalysis.worstShift(from: notes) {
            let from = worst.fromPosition.map { "\($0)e" } ?? "position précédente"
            let to = "\(worst.position)e"
            let movement: String
            switch worst.direction {
            case .down: movement = "En descendant"
            case .up: movement = "En montant"
            case .same: movement = "Sur place"
            }
            let finger = worst.finger == 0 ? "corde à vide" : (worst.finger == 5 ? "pouce" : "\(worst.finger)e doigt")
            let sign = worst.meanCents >= 0 ? "trop haut" : "trop bas"
            items.append(CommentaryItem(
                id: "position-shift",
                title: "Arrivée de déplacement",
                detail: String(
                    format: "%@ de %@ vers %@, ton %@ arrive en moyenne %.0f cents %@ (%d cas).",
                    movement, from, to, finger, abs(worst.meanCents), sign, worst.count
                ),
                advice: "Travaille la descente seule, lentement, avec un bourdon de sol : pose le doigt d'un coup et vérifie la note d'arrivée avant de continuer.",
                level: worst.meanAbsCents > 35 ? .alert : .watch,
                deltaText: nil,
                improving: nil
            ))
        }

        if let glide = PositionAnalysis.parasiteGlideSummary(from: notes) {
            let ratio = Double(glide.parasite) / Double(max(1, glide.total))
            items.append(CommentaryItem(
                id: "position-glide",
                title: "Glissé parasite",
                detail: String(
                    format: "En %de position, tu as tendance à glisser : %d déplacements sur %d arrivent avec un portamento (%.0f %%).",
                    glide.position, glide.parasite, glide.total, ratio * 100
                ),
                advice: "Pose le doigt d'un coup sec pendant que le coude accompagne la main ; le glissé doit rester réservé aux glissandos écrits.",
                level: ratio >= 0.4 ? .alert : .watch,
                deltaText: nil,
                improving: nil
            ))
        }

        if let worstPosition = PositionAnalysis.meanAbsCentsByPosition(from: notes)
            .filter({ $0.count >= 2 })
            .max(by: { $0.cents < $1.cents }), worstPosition.cents >= 25 {
            items.append(CommentaryItem(
                id: "position-accuracy",
                title: "Justesse par position",
                detail: String(
                    format: "En %de position, l'écart moyen est de %.0f cents sur %d notes.",
                    worstPosition.position, worstPosition.cents, worstPosition.count
                ),
                advice: "Isole cette position : joue la note d'arrivée, vérifie-la à la corde à vide ou au bourdon, puis ajoute le déplacement.",
                level: worstPosition.cents > 40 ? .alert : .watch,
                deltaText: nil,
                improving: nil
            ))
        }

        return Array(items.prefix(3))
    }

    // MARK: - Techniques (piqué, glissé)

    private static func techniqueItems(for record: SessionRecord) -> [CommentaryItem] {
        guard let technique = record.technique else { return [] }
        var items: [CommentaryItem] = []

        if technique.piqueUnevenRuns > 0 {
            let deviationValue = technique.piqueWorstDeviation ?? 0
            let deviation = String(format: "%.0f %%", abs(deviationValue) * 100)
            let comparison = deviationValue < 0 ? "de moins" : "de plus"
            let index = technique.piqueWorstIndex.map { "la \($0)e note" } ?? "une note"
            items.append(CommentaryItem(
                id: "technique-pique",
                title: "Piqué inégal",
                detail: "Ton piqué est inégal : \(index) de la série dure \(deviation) \(comparison) que la moyenne (\(technique.piqueUnevenRuns) série(s) concernée(s)).",
                advice: "Vise des notes égales en arrêtant l'archet à la même vitesse à chaque fois, puis accélère seulement quand la série est régulière.",
                level: .watch,
                deltaText: nil,
                improving: nil
            ))
        } else if technique.piqueNotes >= 4, let regularity = technique.piqueRegularity {
            items.append(CommentaryItem(
                id: "technique-pique-good",
                title: "Piqué régulier",
                detail: String(format: "Durées et énergies stables sur %d notes piquées (régularité %.0f %%).", technique.piqueNotes, regularity * 100),
                advice: "Continue à écouter l'égalité des notes plutôt que la vitesse : la régularité précède l'accélération.",
                level: .good,
                deltaText: nil,
                improving: nil
            ))
        }

        if technique.parasiteGlides > 0, let ratio = technique.parasiteGlideRatio {
            items.append(CommentaryItem(
                id: "technique-glide",
                title: "Glissé parasite",
                detail: String(
                    format: "%d déplacement(s) glissé(s) sur %d (%.0f %%) sans glissando écrit.",
                    technique.parasiteGlides,
                    technique.parasiteGlides + technique.voluntaryGlides,
                    ratio * 100
                ),
                advice: "Relâche la pression du doigt pendant le déplacement et laisse le coude guider : le portamento doit être un choix, pas un reste de main qui traîne.",
                level: ratio >= 0.4 ? .alert : .watch,
                deltaText: nil,
                improving: nil
            ))
        } else if technique.voluntaryGlides > 0 {
            items.append(CommentaryItem(
                id: "technique-glide-good",
                title: "Glissando contrôlé",
                detail: "\(technique.voluntaryGlides) glissando(s) écrit(s) détecté(s), sans glissé parasite signalé.",
                advice: "Garde la même pente et la même arrivée nette quand tu réintègres le passage dans le tempo.",
                level: .good,
                deltaText: nil,
                improving: nil
            ))
        }

        return items
    }

    // MARK: - Commentaire global

    private static func globalComment(
        record: SessionRecord,
        score: SessionScore,
        posture: [CommentaryItem],
        sound: [CommentaryItem],
        leftHand: [CommentaryItem],
        positions: [CommentaryItem],
        techniques: [CommentaryItem]
    ) -> String {
        guard score.total > 0 else {
            return "Pas assez de signal analysé pour évaluer cette séance : vérifiez l'éclairage, l'angle de la caméra et la position du micro, puis relancez une séance."
        }

        // Priorité : posture, puis main gauche, puis son, puis techniques.
        // A18 (pouce) reste une hypothèse : il ne passe jamais en alerte.
        let handAlerts = leftHand.filter { $0.level == .alert && !$0.id.contains("A18") }
        let positionAlerts = positions.filter { $0.level == .alert }
        let techniqueAlerts = techniques.filter { $0.level == .alert }
        let priority: String
        if let worst = posture.filter({ $0.level == .alert }).first {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else if let worst = handAlerts.first {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else if let worst = positionAlerts.first {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else if let worst = sound.filter({ $0.level == .alert }).first {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else if let worst = techniqueAlerts.first {
            priority = "Le point prioritaire est « \(worst.title) »."
        } else if let watch = leftHand.first {
            let suffix = watch.id.contains("A18") && !watch.title.lowercased().contains("hypothèse") ? " (hypothèse)" : ""
            priority = "À surveiller : « \(watch.title) »\(suffix)."
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
        if let hand = record.hand, let rate = hand.detectionRate {
            parts.append("main gauche détectée sur \(Int(rate * 100)) % des frames")
        }
        if let stats = record.positionStats, !stats.samples.isEmpty {
            let measured = stats.samples.filter { $0.position != nil }.count
            let ratio = Double(measured) / Double(stats.samples.count)
            parts.append("position estimée pour \(Int(ratio * 100)) % des notes (±1 position)")
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

/// Axe d'un graphique en radar (spider) : une métrique notée de 0 à 100.
struct RadarAxis: Identifiable {
    let name: String
    let value: Double
    var id: String { name }
}

/// Répartition de notes en catégories (pour les graphiques en anneau).
struct NoteBucket: Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

/// Compteur nommé (articulations, etc.).
struct NamedCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

/// Répartition justesse d'un rapport : justes / approchantes / fausses
/// (calculée sur la série des cents note par note).
enum NoteDistribution {
    static func buckets(for record: SessionRecord, tolerance: Double) -> [NoteBucket] {
        guard record.noteCount > 0 else { return [] }
        if record.noteCents.isEmpty {
            // Mode morceau : la série par note n'est pas stockée, on utilise les compteurs.
            return [
                NoteBucket(label: "Justes", count: record.inTuneNotes),
                NoteBucket(label: "Fausses", count: max(0, record.noteCount - record.inTuneNotes))
            ]
        }
        var justes = 0
        var proches = 0
        var fausses = 0
        for cents in record.noteCents {
            switch NoteAccuracy.evaluate(cents: cents, tolerance: tolerance) {
            case .inTune: justes += 1
            case .close: proches += 1
            case .off: fausses += 1
            }
        }
        return [
            NoteBucket(label: "Justes", count: justes),
            NoteBucket(label: "Approchantes", count: proches),
            NoteBucket(label: "Fausses", count: fausses)
        ]
    }
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
    let hnrSeries: [SeriesPoint]
    let bowSeries: [SeriesPoint]
    let postureTotals: [PostureAggregate]
    let best: SessionRecord?
    let worst: SessionRecord?

    // Statistiques complémentaires (fenêtre récente).
    let totalNotes: Int
    let averageDuration: Double?
    let averageHNR: Double?
    let averageVibratoRate: Double?
    let averageVibratoExtent: Double?
    let articulationTotals: [NamedCount]
    let bowAngleConformity: Double?
    let bowZoneConformity: Double?

    /// Axes du graphique en radar : chaque métrique ramenée à 0-100
    /// (plus haut = mieux), calculés sur les moyennes récentes.
    var radar: [RadarAxis] {
        var axes: [RadarAxis] = []
        if let value = averageIntonation {
            axes.append(RadarAxis(name: "Justesse", value: 100 * exp(-value / 20)))
        }
        if let value = averageStability {
            axes.append(RadarAxis(name: "Stabilité", value: 100 * exp(-value / 12)))
        }
        if let hnr = averageHNR {
            axes.append(RadarAxis(name: "Timbre", value: max(0, min(100, (hnr - 5) / 20 * 100))))
        }
        if let value = averageAlertRatio {
            axes.append(RadarAxis(name: "Posture", value: 100 * max(0, 1 - value)))
        }
        if let value = averageSoundingRatio {
            axes.append(RadarAxis(name: "Présence sonore", value: value * 100))
        }
        return axes
    }

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
        let averageHNR = StatsKit.mean(recent.compactMap(\.meanHNR))
        let averageVibratoRate = StatsKit.mean(recent.compactMap(\.meanVibratoRate))
        let averageVibratoExtent = StatsKit.mean(recent.compactMap(\.meanVibratoExtent))
        let averageDuration = StatsKit.mean(recent.filter { $0.duration > 0 }.map(\.duration))

        let bowSessions = recent.compactMap { record -> BowRecord? in
            guard let bow = record.bow, bow.frames > 0 else { return nil }
            return bow
        }
        let bowAngleConformity = bowSessions.isEmpty
            ? nil
            : StatsKit.mean(bowSessions.map { Double($0.goodAngle) / Double($0.frames) * 100 })
        let bowZoneConformity = bowSessions.isEmpty
            ? nil
            : StatsKit.mean(bowSessions.map { Double($0.goodZone) / Double($0.frames) * 100 })

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
        let hnrSeries = series { $0.meanHNR }
        let bowSeries = series { record in
            guard let bow = record.bow, bow.frames > 0 else { return nil }
            return Double(bow.goodAngle) / Double(bow.frames) * 100
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

        // Cumul des articulations, toutes séances confondues.
        var articulation: [String: Int] = [:]
        for record in records {
            for (name, count) in record.articulationCounts ?? [:] {
                articulation[name, default: 0] += count
            }
        }
        let articulationTotals = articulation
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

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
            hnrSeries: hnrSeries,
            bowSeries: bowSeries,
            postureTotals: postureTotals,
            best: best,
            worst: worst,
            totalNotes: records.reduce(0) { $0 + $1.noteCount },
            averageDuration: averageDuration,
            averageHNR: averageHNR,
            averageVibratoRate: averageVibratoRate,
            averageVibratoExtent: averageVibratoExtent,
            articulationTotals: articulationTotals,
            bowAngleConformity: bowAngleConformity,
            bowZoneConformity: bowZoneConformity
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
