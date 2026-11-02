import Foundation

func makeMetrics(shoulderWidth: Double, neckGap: Double, headForward: Double, asymmetry: Double) -> PoseMetrics {
    PoseMetrics(
        valid: true,
        shoulderWidth: shoulderWidth,
        neckGap: neckGap,
        headForwardProxy: headForward,
        headTiltDegrees: nil,
        shoulderAsymmetry: asymmetry
    )
}

func run(profile: SkillProfile, label: String) {
    let rules = PostureRules()
    rules.apply(profile: profile)

    let baseline = makeMetrics(shoulderWidth: 0.30, neckGap: 0.20, headForward: 0.0, asymmetry: 0.01)
    rules.calibrate(Array(repeating: baseline, count: 5))

    let bad = makeMetrics(shoulderWidth: 0.24, neckGap: 0.14, headForward: 0.30, asymmetry: 0.09)
    var now = Date(timeIntervalSince1970: 1_000_000)
    var alerts: [ActiveAlert] = []
    for _ in 0..<70 {
        now = now.addingTimeInterval(0.1)
        alerts = rules.evaluate(bad, now: now)
    }

    let summary = rules.summary()
        .map { "\($0.id):\(Int($0.totalBadSeconds))s/\($0.occurrences)" }
        .joined(separator: " ")
    print("\(label) ALERTS:", alerts.map(\.title).joined(separator: ", "))
    print("\(label) SUMMARY:", summary)
}

@main
struct PostureCheck {
    static func main() {
        run(profile: .beginner, label: "BEGINNER")
        run(profile: .advanced, label: "ADVANCED")
    }
}
