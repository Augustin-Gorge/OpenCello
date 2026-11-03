import Foundation

struct ActiveAlert: Identifiable {
    let ruleID: String
    let title: String
    let message: String
    let since: Date

    var id: String { ruleID }
}

struct RuleSummary {
    let id: String
    let title: String
    let totalBadSeconds: Double
    let occurrences: Int
    let isActive: Bool
}

/// Seuils main gauche (A17-A20), adaptés au niveau. Ils ne déclenchent jamais
/// d'alerte temps réel : ils alimentent le rapport et le profil.
struct HandThresholds {
    let handAngleLimit: Double
    let fingerSpeedLimit: Double
    let elbowMobilityMinimum: Double

    static func forProfile(_ profile: SkillProfile) -> HandThresholds {
        switch profile {
        case .beginner:
            return HandThresholds(handAngleLimit: 18, fingerSpeedLimit: 2.2, elbowMobilityMinimum: 0.03)
        case .intermediate:
            return HandThresholds(handAngleLimit: 15, fingerSpeedLimit: 2.8, elbowMobilityMinimum: 0.05)
        case .advanced:
            return HandThresholds(handAngleLimit: 12, fingerSpeedLimit: 3.4, elbowMobilityMinimum: 0.07)
        }
    }
}

/// État instantané d'une règle pour l'affichage temps réel (jauge de position).
struct LiveRuleStatus: Identifiable {
    let ruleID: String
    let title: String
    let correction: String
    /// 0 = parfaitement dans la zone de confort, 1 = au seuil, > 1 = au-delà
    /// (borné à 1,5 pour l'affichage).
    let severity: Double

    var violated: Bool { severity >= 1 }
    var id: String { ruleID }
}

/// Moteur de règles posture (adapté d'ErgoGuard + heuristiques du papier Purdue).
/// Anti-clignotement : persistance 5 s, affichage minimum 3 s, cooldown 20 s, 2 alertes max.
final class PostureRules {
    struct Baseline {
        var shoulderWidth: Double
        var neckGap: Double
        var headForwardProxy: Double?
    }

    private struct RuleState {
        let id: String
        let title: String
        let message: String
        var candidateSince: Date?
        var alertSince: Date?
        var cooldownUntil: Date = .distantPast
        var lastSampleAt: Date?
        var totalBadSeconds: Double = 0
        var occurrences: Int = 0
    }

    private let persist: TimeInterval = 5
    private let minimumDisplay: TimeInterval = 3
    private let cooldown: TimeInterval = 20

    private var shouldersUpFactor = 0.85
    private var roundedShouldersFactor = 0.85
    private var headForwardMargin = 0.18
    private var asymmetryLimit = 0.06

    private(set) var baseline: Baseline?
    private var states: [RuleState]

    init() {
        states = [
            RuleState(
                id: "A1",
                title: "Tête en avant",
                message: "Reculez doucement la tête au-dessus de la colonne (chin tuck)."
            ),
            RuleState(
                id: "A2",
                title: "Épaules haussées",
                message: "Laissez tomber les épaules ; le cou reste relâché."
            ),
            RuleState(
                id: "A3",
                title: "Épaules voûtées",
                message: "Sternum levé, omoplates basses : ouvrez la cage thoracique."
            ),
            RuleState(
                id: "A4",
                title: "Épaule droite plus haute",
                message: "Relâchez l'épaule droite et laissez peser le coude."
            )
        ]
    }

    func evaluate(_ metrics: PoseMetrics, now: Date = Date()) -> [ActiveAlert] {
        guard let baseline, metrics.valid else {
            return activeAlerts(now: now)
        }

        for index in states.indices {
            var state = states[index]
            let delta = state.lastSampleAt.map { min(max(now.timeIntervalSince($0), 0), 0.5) } ?? 0
            state.lastSampleAt = now

            let isBad = isViolated(state.id, metrics: metrics, baseline: baseline)
            if isBad {
                state.totalBadSeconds += delta
                if state.candidateSince == nil {
                    state.candidateSince = now
                }
            } else {
                state.candidateSince = nil
            }

            if let candidate = state.candidateSince,
               state.alertSince == nil,
               now.timeIntervalSince(candidate) >= persist,
               now >= state.cooldownUntil {
                state.alertSince = now
                state.occurrences += 1
            }

            if let alertSince = state.alertSince,
               !isBad,
               now.timeIntervalSince(alertSince) >= minimumDisplay {
                state.alertSince = nil
                state.cooldownUntil = now.addingTimeInterval(cooldown)
            }

            states[index] = state
        }

        return activeAlerts(now: now)
    }

    private func isViolated(_ id: String, metrics: PoseMetrics, baseline: Baseline) -> Bool {
        switch id {
        case "A1":
            guard let proxy = metrics.headForwardProxy,
                  let base = baseline.headForwardProxy else { return false }
            return proxy > base + headForwardMargin
        case "A2":
            return baseline.neckGap > 0 && metrics.neckGap < baseline.neckGap * shouldersUpFactor
        case "A3":
            return metrics.shoulderWidth < baseline.shoulderWidth * roundedShouldersFactor
        case "A4":
            return metrics.shoulderAsymmetry > asymmetryLimit
        default:
            return false
        }
    }

    // MARK: - Statut temps réel (jauge par règle)

    /// Statut instantané de chaque règle, indépendant de la machine à états des alertes.
    /// Utilisé par le panneau « Position en direct » pendant la séance.
    func liveStatus(for metrics: PoseMetrics) -> [LiveRuleStatus] {
        guard let baseline, metrics.valid else { return [] }
        return states.map { state in
            LiveRuleStatus(
                ruleID: state.id,
                title: state.title,
                correction: state.message,
                severity: severityValue(state.id, metrics: metrics, baseline: baseline)
            )
        }
    }

    private func severityValue(_ id: String, metrics: PoseMetrics, baseline: Baseline) -> Double {
        let clamp: (Double) -> Double = { min(max($0, 0), 1.5) }
        switch id {
        case "A1":
            guard let proxy = metrics.headForwardProxy,
                  let base = baseline.headForwardProxy,
                  headForwardMargin > 0 else { return 0 }
            return clamp((proxy - base) / headForwardMargin)
        case "A2":
            let threshold = baseline.neckGap * shouldersUpFactor
            guard threshold > 0 else { return 0 }
            return clamp(1 - metrics.neckGap / threshold)
        case "A3":
            let threshold = baseline.shoulderWidth * roundedShouldersFactor
            guard threshold > 0 else { return 0 }
            return clamp(1 - metrics.shoulderWidth / threshold)
        case "A4":
            guard asymmetryLimit > 0 else { return 0 }
            return clamp(metrics.shoulderAsymmetry / asymmetryLimit)
        default:
            return 0
        }
    }

    static let handRuleIDs = ["A17", "A18", "A19", "A20"]

    static func handThresholds(for profile: SkillProfile) -> HandThresholds {
        HandThresholds.forProfile(profile)
    }

    static func handRuleTitle(for ruleID: String) -> String {
        switch ruleID {
        case "A17": return "Main gauche cassée"
        case "A18": return "Pouce gauche crispé (hypothèse)"
        case "A19": return "Doigts raides ou frappe brutale"
        case "A20": return "Coude gauche qui ne guide pas"
        default: return "Main gauche"
        }
    }

    static func handCorrection(for ruleID: String) -> String {
        switch ruleID {
        case "A17":
            return "Allonge le poignet dans la ligne de l'avant-bras : la main reste dans l'axe du 3e doigt, sans casser vers l'intérieur."
        case "A18":
            return "Vérifie que le pouce glisse derrière le manche sans serrer ; relâche-le entre deux notes. C'est une hypothèse, pas une certitude."
        case "A19":
            return "Lève les doigts juste au-dessus de la corde et pose-les sans frapper : cherche la souplesse, pas la force."
        case "A20":
            return "Laisse le coude accompagner la main pendant le déplacement : c'est lui qui guide la descente, pas les doigts seuls."
        default:
            return ""
        }
    }

    /// Conseil de correction associé à une règle (aussi utilisé dans les rapports).
    static func correction(for ruleID: String) -> String {
        switch ruleID {
        case "A1":
            return "Reculez doucement la tête au-dessus de la colonne (chin tuck)."
        case "A2":
            return "Laissez tomber les épaules ; le cou reste relâché."
        case "A3":
            return "Sternum levé, omoplates basses : ouvrez la cage thoracique."
        case "A4":
            return "Relâchez l'épaule droite et laissez peser le coude."
        default:
            return ""
        }
    }

    func apply(profile: SkillProfile) {
        switch profile {
        case .beginner:
            shouldersUpFactor = 0.88
            roundedShouldersFactor = 0.88
            headForwardMargin = 0.14
            asymmetryLimit = 0.05
        case .intermediate:
            shouldersUpFactor = 0.85
            roundedShouldersFactor = 0.85
            headForwardMargin = 0.18
            asymmetryLimit = 0.06
        case .advanced:
            shouldersUpFactor = 0.80
            roundedShouldersFactor = 0.80
            headForwardMargin = 0.22
            asymmetryLimit = 0.08
        }
    }

    private func activeAlerts(now: Date) -> [ActiveAlert] {
        states
            .filter { $0.alertSince != nil }
            .sorted { $0.totalBadSeconds > $1.totalBadSeconds }
            .prefix(2)
            .map {
                ActiveAlert(
                    ruleID: $0.id,
                    title: $0.title,
                    message: $0.message,
                    since: $0.alertSince ?? now
                )
            }
    }

    func calibrate(_ samples: [PoseMetrics]) {
        let valid = samples.filter { $0.valid }
        guard !valid.isEmpty else { return }

        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }

        let width = median(valid.map { $0.shoulderWidth }) ?? 0
        let gap = median(valid.map { $0.neckGap }) ?? 0
        let proxy = median(valid.compactMap { $0.headForwardProxy })
        guard width > 0.01, gap > 0 else { return }

        baseline = Baseline(shoulderWidth: width, neckGap: gap, headForwardProxy: proxy)
    }

    var baselineDescription: String {
        guard let baseline else { return "Baseline posture : non calibrée" }
        return String(
            format: "Baseline : largeur épaules %.3f · écart cou %.3f",
            baseline.shoulderWidth,
            baseline.neckGap
        )
    }

    func reset() {
        for index in states.indices {
            states[index].candidateSince = nil
            states[index].alertSince = nil
            states[index].cooldownUntil = .distantPast
            states[index].lastSampleAt = nil
            states[index].totalBadSeconds = 0
            states[index].occurrences = 0
        }
    }

    func summary() -> [RuleSummary] {
        states.map {
            RuleSummary(
                id: $0.id,
                title: $0.title,
                totalBadSeconds: $0.totalBadSeconds,
                occurrences: $0.occurrences,
                isActive: $0.alertSince != nil
            )
        }
    }
}
