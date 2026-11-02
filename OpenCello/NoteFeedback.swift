import SwiftUI

enum NoteAccuracy {
    case inTune
    case close
    case off

    var label: String {
        switch self {
        case .inTune: return "Juste"
        case .close: return "Approchant"
        case .off: return "Faux"
        }
    }

    var color: Color {
        switch self {
        case .inTune: return .green
        case .close: return .orange
        case .off: return .red
        }
    }

    /// B1 : évalue la justesse d'une note par rapport à la tolérance (cents).
    static func evaluate(cents: Double, tolerance: Double) -> NoteAccuracy {
        if abs(cents) <= tolerance { return .inTune }
        if abs(cents) <= tolerance * 2 { return .close }
        return .off
    }
}

struct NoteFeedback {
    let name: String
    let cents: Double
    let stability: Double
    let hnr: Double
    let accuracy: NoteAccuracy
    let isStable: Bool
    let vibratoRate: Double?
    let vibratoExtent: Double?
    let articulation: Articulation?
}
