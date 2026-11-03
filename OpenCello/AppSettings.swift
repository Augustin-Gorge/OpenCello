import Foundation
import Combine

enum SkillProfile: String, CaseIterable, Codable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Débutant"
        case .intermediate: return "Intermédiaire"
        case .advanced: return "Avancé"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Contrôles stricts, priorités santé et bases"
        case .intermediate: return "Équilibre entre exigence et liberté"
        case .advanced: return "Tolérances larges, focus tension et mobilité"
        }
    }
}

/// Réglages persistants de l'application (profil, diapason, tolérances).
final class AppSettings: ObservableObject {
    @Published var profile: SkillProfile {
        didSet { defaults.set(profile.rawValue, forKey: Key.profile) }
    }
    @Published var a4: Double {
        didSet { defaults.set(a4, forKey: Key.a4) }
    }
    @Published var intonationTolerance: Double {
        didSet { defaults.set(intonationTolerance, forKey: Key.intonation) }
    }
    @Published var stabilityTolerance: Double {
        didSet { defaults.set(stabilityTolerance, forKey: Key.stability) }
    }
    @Published var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: Key.onboarding) }
    }
    /// Opt-in explicite : enregistre la vidéo locale de la séance (aucun envoi).
    @Published var recordSessionVideo: Bool {
        didSet { defaults.set(recordSessionVideo, forKey: Key.recordVideo) }
    }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let profile = "settings.profile"
        static let a4 = "settings.a4"
        static let intonation = "settings.intonationTolerance"
        static let stability = "settings.stabilityTolerance"
        static let onboarding = "settings.hasSeenOnboarding"
        static let recordVideo = "settings.recordSessionVideo"
    }

    init() {
        profile = defaults.string(forKey: Key.profile)
            .flatMap(SkillProfile.init(rawValue:)) ?? .intermediate
        a4 = defaults.object(forKey: Key.a4) as? Double ?? 440
        intonationTolerance = defaults.object(forKey: Key.intonation) as? Double ?? 25
        stabilityTolerance = defaults.object(forKey: Key.stability) as? Double ?? 15
        hasSeenOnboarding = defaults.bool(forKey: Key.onboarding)
        recordSessionVideo = defaults.bool(forKey: Key.recordVideo)
    }
}
