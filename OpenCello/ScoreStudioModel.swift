import Foundation
import SwiftUI
import AppKit
import SheetMusic
import SheetMusicCore
import SheetMusicLayout

/// Score du paquet de rendu (distinct du `Score` simplifié de l'app).
typealias StudioScore = SheetMusicCore.Score

/// Atelier d'une partition MusicXML : aperçu intégré + édition déléguée à
/// **MuseScore**, l'éditeur open source de référence.
///
/// Aller-retour : le MusicXML est converti en `.mscz` (format natif de
/// MuseScore) pour l'édition, puis reconverti en MusicXML à chaque
/// enregistrement dans MuseScore. L'app ne réimplémente donc aucune fonction
/// d'édition : elle utilise celles de MuseScore (notes, liaisons, nuances,
/// articulations, doigtés, mise en page, lecture…).
@MainActor
final class ScoreStudioModel: ObservableObject {
    let url: URL

    @Published private(set) var score: StudioScore?
    @Published private(set) var isLoading = true
    @Published private(set) var status: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var scoreVersion = 0
    @Published private(set) var partCount = 0
    @Published private(set) var measureCount = 0
    @Published private(set) var museScoreApp: URL?
    @Published private(set) var museScoreVersion: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isWatching = false
    @Published private(set) var lastSync: Date?

    /// Appelé quand le MusicXML a changé et que le `Score` de l'app a été
    /// reconstruit (pour que le mode morceau utilise les modifications).
    var onReloaded: ((Score) -> Void)?

    private var timer: Timer?
    private var msczDate: Date?
    private var musicXMLDate: Date?
    private var pendingSince: Date?
    private var ignoreUntil = Date.distantPast

    var msczURL: URL {
        url.deletingPathExtension().appendingPathExtension("mscz")
    }

    var isMuseScoreAvailable: Bool { museScoreApp != nil }
    var hasEditFile: Bool { FileManager.default.fileExists(atPath: msczURL.path) }

    init(url: URL) {
        self.url = url
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Chargement

    func start() {
        detectMuseScore()
        load()
        syncIfNeeded()
    }

    func load() {
        isLoading = true
        do {
            let data = try Data(contentsOf: url)
            let parsed = try SheetMusic.loadScore(musicXMLData: data)
            score = parsed
            partCount = parsed.parts.count
            measureCount = parsed.parts.first?.staves.first?.measures.count ?? 0
            musicXMLDate = modificationDate(of: url)
            status = "Aperçu prêt"
            errorMessage = nil
        } catch {
            errorMessage = "Lecture impossible : \(error.localizedDescription)"
        }
        isLoading = false
    }

    func reload() {
        reloadFromDisk(notify: true)
        status = "Rechargé"
    }

    private func reloadFromDisk(notify: Bool) {
        do {
            let data = try Data(contentsOf: url)
            let parsed = try SheetMusic.loadScore(musicXMLData: data)
            score = parsed
            partCount = parsed.parts.count
            measureCount = parsed.parts.first?.staves.first?.measures.count ?? 0
            scoreVersion += 1
            musicXMLDate = modificationDate(of: url)
            if notify, let appScore = try? MusicXMLParser.parse(data: data) {
                onReloaded?(appScore)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Rechargement impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - MuseScore

    func detectMuseScore() {
        let app = Self.findMuseScoreApplication()
        museScoreApp = app
        if let app {
            museScoreVersion = Bundle(url: app)?
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        } else {
            museScoreVersion = nil
        }
    }

    static func findMuseScoreApplication() -> URL? {
        let workspace = NSWorkspace.shared
        let identifiers = [
            "org.musescore.MuseScore",
            "org.musescore.MuseScore4",
            "org.musescore.MuseScore3",
        ]
        for identifier in identifiers {
            if let url = workspace.urlForApplication(withBundleIdentifier: identifier) {
                return url
            }
        }
        let candidates = [
            "/Applications/MuseScore 4.app",
            "/Applications/MuseScore 3.app",
            NSHomeDirectory() + "/Applications/MuseScore 4.app",
            NSHomeDirectory() + "/Applications/MuseScore 3.app",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static func museScoreCLI(for app: URL) -> URL? {
        let macos = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let names = ["mscore", "musescore", "MuseScore 4", "MuseScore 3"]
        for name in names {
            let url = macos.appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: macos,
            includingPropertiesForKeys: nil
        ) {
            for url in contents where url.lastPathComponent.lowercased().contains("score") {
                if FileManager.default.isExecutableFile(atPath: url.path) {
                    return url
                }
            }
        }
        return nil
    }

    func openInMuseScore() {
        guard let app = museScoreApp else {
            errorMessage = "MuseScore n'est pas installé."
            return
        }
        isBusy = true
        status = "Préparation de l'édition…"
        Task {
            do {
                let editURL = try await ensureEditFile(app: app)
                await open(editURL, with: app)
                beginWatching()
                status = "MuseScore ouvert. Enregistrez avec ⌘S : l'aperçu se met à jour ici."
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func installMuseScore() {
        guard let url = URL(string: "https://musescore.org/fr/download") else { return }
        NSWorkspace.shared.open(url)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([hasEditFile ? msczURL : url])
    }

    /// Convertit le MusicXML en `.mscz` si nécessaire (via la CLI de MuseScore).
    private func ensureEditFile(app: URL) async throws -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: msczURL.path) { return msczURL }
        guard let cli = Self.museScoreCLI(for: app) else {
            throw StudioError.cliMissing
        }
        let (status, log) = try await Self.runCLI(
            cli,
            arguments: ["-o", msczURL.path, url.path]
        )
        guard status == 0, fm.fileExists(atPath: msczURL.path) else {
            throw StudioError.conversionFailed(log)
        }
        msczDate = modificationDate(of: msczURL)
        return msczURL
    }

    private func open(_ file: URL, with app: URL) async {
        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open(
                [file],
                withApplicationAt: app,
                configuration: configuration
            ) { _, error in
                if let error {
                    Task { @MainActor in
                        self.errorMessage = "Ouverture dans MuseScore impossible : \(error.localizedDescription)"
                    }
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Surveillance des modifications

    func beginWatching() {
        guard timer == nil else { return }
        msczDate = modificationDate(of: msczURL)
        musicXMLDate = modificationDate(of: url)
        isWatching = true
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
        isWatching = false
    }

    private func poll() {
        guard !isBusy else { return }
        let now = Date()

        // MuseScore a-t-il écrit un nouveau .mscz ?
        if let date = modificationDate(of: msczURL) {
            if let previous = msczDate, date > previous.addingTimeInterval(0.2) {
                msczDate = date
                pendingSince = now
            } else if msczDate == nil {
                msczDate = date
            }
        }

        if let pendingSince,
           now.timeIntervalSince(pendingSince) > 1.2,
           now > ignoreUntil {
            self.pendingSince = nil
            syncFromMuseScore()
            return
        }

        // Édition externe du MusicXML (autre outil) : rafraîchir l'aperçu.
        if let date = modificationDate(of: url),
           let previous = musicXMLDate,
           date > previous.addingTimeInterval(0.2),
           now > ignoreUntil {
            musicXMLDate = date
            reloadFromDisk(notify: true)
            status = "MusicXML rechargé"
        }
    }

    /// Reconversion `.mscz` → MusicXML après un enregistrement dans MuseScore.
    func syncFromMuseScore() {
        guard let app = museScoreApp,
              let cli = Self.museScoreCLI(for: app),
              FileManager.default.fileExists(atPath: msczURL.path) else {
            return
        }
        isBusy = true
        ignoreUntil = Date().addingTimeInterval(4)
        status = "Récupération des modifications de MuseScore…"
        Task {
            let temporary = url.deletingLastPathComponent()
                .appendingPathComponent(".opencello-sync-\(UUID().uuidString).musicxml")
            defer { try? FileManager.default.removeItem(at: temporary) }
            do {
                let (code, log) = try await Self.runCLI(
                    cli,
                    arguments: ["-o", temporary.path, msczURL.path]
                )
                guard code == 0, FileManager.default.fileExists(atPath: temporary.path) else {
                    throw StudioError.conversionFailed(log)
                }
                let data = try Data(contentsOf: temporary)
                _ = try MusicXMLParser.parse(data: data)
                _ = try SheetMusic.loadScore(musicXMLData: data)
                if FileManager.default.fileExists(atPath: url.path) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
                } else {
                    try FileManager.default.moveItem(at: temporary, to: url)
                }
                ignoreUntil = Date().addingTimeInterval(2)
                msczDate = modificationDate(of: msczURL)
                musicXMLDate = modificationDate(of: url)
                reloadFromDisk(notify: true)
                lastSync = Date()
                status = "Modifications MuseScore importées"
                errorMessage = nil
            } catch {
                errorMessage = "Import depuis MuseScore impossible : \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    /// À la fermeture : récupère un dernier enregistrement MuseScore non
    /// encore importé (le `.mscz` est plus récent que le MusicXML).
    func flushPendingSync() {
        guard let mscz = modificationDate(of: msczURL),
              let xml = modificationDate(of: url),
              mscz > xml.addingTimeInterval(1) else { return }
        syncFromMuseScore()
    }

    /// Au démarrage : si le `.mscz` est plus récent que le MusicXML, on
    /// récupère les changements avant d'afficher.
    private func syncIfNeeded() {
        guard let mscz = modificationDate(of: msczURL),
              let xml = modificationDate(of: url),
              mscz > xml.addingTimeInterval(1),
              museScoreApp != nil else { return }
        syncFromMuseScore()
    }

    // MARK: - Utilitaires

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private static func runCLI(
        _ executable: URL,
        arguments: [String]
    ) async throws -> (Int32, String) {
        let log = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencello-mscore-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        defer { try? FileManager.default.removeItem(at: log) }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = handle
        process.standardError = handle
        process.standardInput = FileHandle.nullDevice

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                try? handle.close()
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                try? handle.close()
                continuation.resume(throwing: error)
            }
        }
        let data = (try? Data(contentsOf: log)) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (status, String(text.suffix(2_000)))
    }
}

enum StudioError: LocalizedError {
    case cliMissing
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cliMissing:
            return "La ligne de commande de MuseScore est introuvable. "
                + "Réinstallez MuseScore depuis musescore.org."
        case let .conversionFailed(log):
            let detail = log.isEmpty ? "" : "\n\n\(log)"
            return "MuseScore n'a pas pu convertir le fichier.\(detail)"
        }
    }
}
