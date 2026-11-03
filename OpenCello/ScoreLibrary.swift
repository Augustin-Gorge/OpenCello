import Foundation

/// Bibliothèque locale des partitions de travail de l'app.
///
/// Tout est rangé sous `~/Library/Application Support/OpenCello/Scores/`,
/// un dossier par œuvre, avec le PDF d'origine et le MusicXML converti côte
/// à côte (même nom de base). La vérification « le MusicXML existe déjà »
/// se fait donc par simple présence du fichier frère — aucune base à tenir.
enum ScoreLibrary {

    /// Racine de la bibliothèque (créée à la demande).
    static var rootDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("OpenCello", isDirectory: true)
            .appendingPathComponent("Scores", isDirectory: true)
    }

    @discardableResult
    static func ensureRoot() throws -> URL {
        let url = rootDirectory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Dossier d'une œuvre ; le titre vient d'IMSLP ou du nom du fichier.
    static func folder(for workTitle: String) -> URL {
        rootDirectory.appendingPathComponent(
            sanitizedComponent(workTitle.isEmpty ? "Sans titre" : workTitle),
            isDirectory: true
        )
    }

    /// Enregistre un PDF téléchargé (IMSLP) ou importé.
    @discardableResult
    static func storePDF(data: Data, workTitle: String, fileName: String) throws -> URL {
        try ensureRoot()
        let folder = folder(for: workTitle)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var name = sanitizedComponent(fileName)
        if !name.lowercased().hasSuffix(".pdf") { name += ".pdf" }
        let target = folder.appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        return target
    }

    /// Importe un PDF choisi par l'utilisateur (accès security-scoped).
    @discardableResult
    static func importPDF(from source: URL, workTitle: String) throws -> URL {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: source)
        var title = workTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = source.deletingPathExtension().lastPathComponent
        }
        return try storePDF(data: data, workTitle: title, fileName: source.lastPathComponent)
    }

    /// MusicXML associé à un PDF : même dossier, même nom de base.
    static func musicXMLURL(for pdf: URL) -> URL {
        pdf.deletingPathExtension().appendingPathExtension("musicxml")
    }

    /// MusicXML déjà présent pour ce PDF, s'il existe.
    static func existingMusicXML(for pdf: URL) -> URL? {
        let url = musicXMLURL(for: pdf)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Tous les MusicXML de la bibliothèque (pour un futur sélecteur).
    static func allMusicXML() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var urls: [URL] = []
        for case let url as URL in enumerator
        where url.pathExtension.lowercased() == "musicxml" {
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
    }

    /// Composant de chemin sûr (pas de `/`, `:` ni caractère de contrôle).
    static func sanitizedComponent(_ raw: String) -> String {
        var name = raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init)
            .joined()
        if name.count > 90 {
            name = String(name.prefix(90)).trimmingCharacters(in: .whitespaces)
        }
        return name.isEmpty ? "Sans titre" : name
    }
}
