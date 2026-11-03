import Foundation

/// État de la conversion PDF → MusicXML dans l'UI.
enum OMRState: Equatable {
    case idle
    case running(String)
    case ready(URL)
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .idle: return ""
        case let .running(text): return text
        case let .ready(url): return "MusicXML : \(url.lastPathComponent)"
        case let .failed(message): return message
        }
    }
}

enum OMRServiceError: LocalizedError {
    case audiverisMissing
    case cancelled
    case failed(status: Int32, log: String)
    case noOutput(log: String)

    var errorDescription: String? {
        switch self {
        case .audiverisMissing:
            return "Audiveris n'est pas installé. Téléchargez-le sur audiveris.org "
                + "(outil externe, licence AGPL) puis relancez la conversion."
        case .cancelled:
            return "Conversion annulée."
        case let .failed(status, log):
            let detail = log.isEmpty ? "" : "\n\n\(log)"
            return "Audiveris a échoué (code \(status)).\(detail)"
        case let .noOutput(log):
            let detail = log.isEmpty ? "" : "\n\n\(log)"
            return "Audiveris n'a produit aucun MusicXML exploitable.\(detail)"
        }
    }
}

/// Lance Audiveris (outil externe AGPL, jamais empaqueté) sur un PDF et
/// récupère le MusicXML produit (décompression `.mxl`, filtre `META-INF`).
final class ScoreOMR: @unchecked Sendable {
    static let shared = ScoreOMR()

    private let stateQueue = DispatchQueue(label: "fr.opencello.omr.state")
    private var activeProcess: Process?
    private var cancelled = false

    private init() {}

    /// Emplacements usuels d'Audiveris, puis `PATH`.
    static func audiverisExecutable() -> URL? {
        let fm = FileManager.default
        let candidates = [
            "/Applications/Audiveris.app/Contents/MacOS/Audiveris",
            NSHomeDirectory() + "/Applications/Audiveris.app/Contents/MacOS/Audiveris",
            "/opt/homebrew/bin/audiveris",
            "/usr/local/bin/audiveris",
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["audiveris"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, fm.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        } catch {
            return nil
        }
        return nil
    }

    func cancel() {
        let process: Process? = stateQueue.sync {
            cancelled = true
            return activeProcess
        }
        if process?.isRunning == true { process?.terminate() }
    }

    /// Convertit `pdf` et écrit le MusicXML à `musicXML`.
    /// Retourne la fin du journal d'Audiveris.
    @discardableResult
    func convert(pdf: URL, musicXML: URL) async throws -> String {
        guard let executable = Self.audiverisExecutable() else {
            throw OMRServiceError.audiverisMissing
        }
        stateQueue.sync { cancelled = false }

        // Évite qu'App Nap ralentisse fortement Audiveris quand l'app est en
        // arrière-plan (constaté : ~2 min au lieu de ~14 s).
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Conversion OMR avec Audiveris"
        )
        defer { ProcessInfo.processInfo.endActivity(activity) }

        let fm = FileManager.default
        let work = fm.temporaryDirectory
            .appendingPathComponent("opencello-omr-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let logURL = work.appendingPathComponent("audiveris.log")
        fm.createFile(atPath: logURL.path, contents: nil)

        let status = try await Self.run(
            executable,
            arguments: ["-batch", "-transcribe", "-export",
                        "-output", work.path, pdf.path],
            logURL: logURL,
            timeout: 1_200,
            owner: self
        )
        let log = Self.logTail(logURL)

        let wasCancelled = stateQueue.sync { cancelled }
        if wasCancelled { throw OMRServiceError.cancelled }
        guard status == 0 else {
            throw OMRServiceError.failed(status: status, log: log)
        }

        let source = try Self.findMusicXML(in: work, log: log)

        // Écriture atomique : on valide une copie temporaire avant de
        // remplacer le MusicXML existant (une sortie Audiveris invalide ne
        // doit jamais détruire une partition déjà valide).
        let destinationFolder = musicXML.deletingLastPathComponent()
        try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let temporary = destinationFolder
            .appendingPathComponent(".opencello-omr-\(UUID().uuidString).musicxml")
        defer { try? fm.removeItem(at: temporary) }
        if fm.fileExists(atPath: temporary.path) {
            try fm.removeItem(at: temporary)
        }
        try fm.copyItem(at: source, to: temporary)

        let document = try XMLDocument(
            contentsOf: temporary,
            options: [.nodeLoadExternalEntitiesNever]
        )
        guard document.rootElement()?.name == "score-partwise" else {
            throw OMRServiceError.noOutput(log: log)
        }
        if fm.fileExists(atPath: musicXML.path) {
            _ = try fm.replaceItemAt(musicXML, withItemAt: temporary)
        } else {
            try fm.moveItem(at: temporary, to: musicXML)
        }
        return log
    }

    // MARK: - Exécution du sous-processus

    private static func run(
        _ executable: URL,
        arguments: [String],
        logURL: URL,
        timeout: TimeInterval,
        owner: ScoreOMR
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.qualityOfService = .userInitiated
        let handle = try FileHandle(forWritingTo: logURL)
        process.standardOutput = handle
        process.standardError = handle
        process.standardInput = FileHandle.nullDevice

        owner.stateQueue.sync { owner.activeProcess = process }

        // Filet de sécurité : tuer un Audiveris bloqué. Le travail normal
        // annule la closure en terminant bien avant.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            if process.isRunning { process.terminate() }
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                try? handle.close()
                owner.stateQueue.sync { owner.activeProcess = nil }
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                try? handle.close()
                owner.stateQueue.sync { owner.activeProcess = nil }
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Récupération du MusicXML

    private static func findMusicXML(in directory: URL, log: String) throws -> URL {
        let fm = FileManager.default
        var mxl: [URL] = []
        var plain: [URL] = []
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw OMRServiceError.noOutput(log: log)
        }
        for case let url as URL in enumerator {
            guard !url.path.contains("/META-INF/") else { continue }
            switch url.pathExtension.lowercased() {
            case "mxl": mxl.append(url)
            case "musicxml", "xml": plain.append(url)
            default: break
            }
        }
        if let archive = mxl.sorted(by: { size(of: $0) > size(of: $1) }).first {
            return try unpackMXL(archive, in: directory, log: log)
        }
        if let file = plain.sorted(by: { size(of: $0) > size(of: $1) }).first {
            return file
        }
        throw OMRServiceError.noOutput(log: log)
    }

    private static func unpackMXL(_ archive: URL, in directory: URL, log: String) throws -> URL {
        let fm = FileManager.default
        let destination = directory.appendingPathComponent("unpacked", isDirectory: true)
        try? fm.removeItem(at: destination)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, destination.path]
        ditto.standardOutput = FileHandle.nullDevice
        ditto.standardError = FileHandle.nullDevice
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else {
            throw OMRServiceError.noOutput(log: log)
        }

        // Le descripteur `.mxl` nomme le fichier racine ; on le préfère à une
        // recherche par taille (plusieurs XML peuvent coexister).
        let container = destination.appendingPathComponent("META-INF/container.xml")
        if let document = try? XMLDocument(
            contentsOf: container,
            options: [.nodeLoadExternalEntitiesNever]
        ),
            let rootfile = document.rootElement()?
                .elements(forName: "rootfiles").first?
                .elements(forName: "rootfile").first,
            let path = rootfile.attribute(forName: "full-path")?.stringValue {
            let candidate = destination.appendingPathComponent(path)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }

        guard let enumerator = fm.enumerator(
            at: destination,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw OMRServiceError.noOutput(log: log)
        }
        var candidates: [URL] = []
        for case let url as URL in enumerator {
            guard !url.path.contains("/META-INF/") else { continue }
            if ["xml", "musicxml"].contains(url.pathExtension.lowercased()) {
                candidates.append(url)
            }
        }
        guard let best = candidates.sorted(by: { size(of: $0) > size(of: $1) }).first else {
            throw OMRServiceError.noOutput(log: log)
        }
        return best
    }

    private static func size(of url: URL) -> Int {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }

    private static func logTail(_ url: URL, limit: Int = 2_500) -> String {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.suffix(limit))
    }
}
