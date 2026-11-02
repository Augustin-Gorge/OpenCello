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
