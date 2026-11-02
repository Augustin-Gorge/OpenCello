import Foundation

enum Articulation: String, CaseIterable {
    case legato = "Legato"
    case detache = "Détaché"
    case martele = "Martelé"
    case staccato = "Staccato"
    case spiccato = "Spiccato"
    case sautille = "Sautillé"
    case bariolage = "Bariolage"
    case indetermine = "Indéterminé"
}

struct ArticulationFeatures {
    let duration: Double
    let attackTime: Double
    let tailRatio: Double
    let rmsVariation: Double
    let gapBefore: Double
    let pitchChange: Double
    let notesPerSecond: Double
}

/// Classifieur heuristique (MVP). Il ne prétend pas à 85 % de précision :
/// il donne une indication prudente, et « Indéterminé » en cas de doute.
enum ArticulationClassifier {
    static func classify(_ features: ArticulationFeatures) -> Articulation {
        if features.sautilleLikely {
            return .sautille
        }
        if features.bariolageLikely {
            return .bariolage
        }
        if features.staccatoLikely {
            return .staccato
        }
        if features.spiccatoLikely {
            return .spiccato
        }
        if features.marteleLikely {
            return .martele
        }
        if features.legatoLikely {
            return .legato
        }
        if features.detacheLikely {
            return .detache
        }
        return .indetermine
    }
}

private extension ArticulationFeatures {
    var sautilleLikely: Bool {
        duration < 0.22 && notesPerSecond >= 6 && gapBefore < 0.04
    }

    var bariolageLikely: Bool {
        pitchChange >= 2.5 && duration < 0.4 && notesPerSecond >= 2 && gapBefore < 0.06
    }

    var staccatoLikely: Bool {
        duration < 0.20 && attackTime < 0.035 && gapBefore > 0.035
    }

    var spiccatoLikely: Bool {
        duration < 0.45 && tailRatio < 0.45 && gapBefore > 0.035 && attackTime < 0.06
    }

    var marteleLikely: Bool {
        attackTime < 0.035 && duration >= 0.20 && (tailRatio < 0.75 || gapBefore > 0.05)
    }

    var legatoLikely: Bool {
        duration >= 0.45 && gapBefore < 0.05 && rmsVariation < 0.4 && attackTime > 0.04
    }

    var detacheLikely: Bool {
        duration >= 0.25 && gapBefore > 0.06 && rmsVariation < 0.5
    }
}
