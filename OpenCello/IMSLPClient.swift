import Foundation

// MARK: - Modèles IMSLP

struct IMSLPWork: Identifiable, Decodable {
    let title: String
    let snippet: String?

    var id: String { title }

    var cleanSnippet: String {
        guard let snippet else { return "" }
        var cleaned = snippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct IMSLPSearchEnvelope: Decodable {
    struct Query: Decodable {
        let search: [IMSLPWork]?
    }
    let query: Query?
}

struct IMSLPSearchOutcome {
    let works: [IMSLPWork]
    let composerSurname: String?
    let usedFallback: Bool
}

struct IMSLPComposer: Identifiable, Codable {
    let id: String
    let name: String
    let permlink: String?

    var surname: String {
        name.split(separator: ",", maxSplits: 1).first.map(String.init) ?? name
    }
}

struct ComposerEntry {
    let composer: IMSLPComposer
    let surnameTokens: [String]
    let givenTokens: [String]
}

enum IMSLPError: LocalizedError {
    case http
    case decoding
    case fileUnavailable
    case notAPDF

    var errorDescription: String? {
        switch self {
        case .http: return "IMSLP n'a pas répondu correctement. Vérifiez la connexion."
        case .decoding: return "Réponse IMSLP illisible."
        case .fileUnavailable: return "Page de téléchargement IMSLP illisible ou fichier absent."
        case .notAPDF: return "Le fichier téléchargé n'est pas un PDF."
        }
    }
}

/// Un fichier PDF proposé sur une page d'œuvre IMSLP.
struct IMSLPScoreFile: Identifiable {
    let name: String
    let description: String
    let copyright: String
    /// Index du lien `Special:ImagefromIndex` ; nil si le repérage HTML a échoué.
    let index: Int?

    var id: String { "\(index.map(String.init) ?? "?"):\(name)" }

    /// Statut « Public Domain » affiché par IMSLP (indicatif : la validité
    /// dépend toujours de la juridiction de l'utilisateur).
    var isPublicDomain: Bool { copyright.lowercased().contains("public domain") }
}

// MARK: - Client

/// Client IMSLP tolérant :
/// - index complet des compositeurs (API ISCR paginée) chargé en arrière-plan et mis en cache ;
/// - détection floue du compositeur (accents, fautes, ordre des mots) ;
/// - plan de requêtes de repli (variantes de frappe, traits d'union, compositeur seul) ;
/// - reclassement local par recouvrement de tokens + distance d'édition.
final class IMSLPClient {
    static let shared = IMSLPClient()

    private let userAgent = "OpenCello/0.1 (macOS; educational; local-only app)"
    private let cacheURL: URL?
    private let lock = NSLock()
    private var index: [ComposerEntry] = []
    private var loadingComposers = false
    private var searchCache: [String: IMSLPSearchOutcome] = [:]

    private static let stopwords: Set<String> = [
        "de", "du", "des", "la", "le", "les", "un", "une", "et", "en", "pour", "avec",
        "sur", "dans", "au", "aux", "the", "and", "of", "a", "op", "opus", "no", "n"
    ]

    /// Termes musicaux qui ne doivent jamais être pris pour un nom de compositeur.
    private static let musicalTerms: Set<String> = [
        "allegro", "adagio", "andante", "presto", "largo", "scherzo", "sonata", "sonate",
        "suite", "concerto", "etude", "nocturne", "waltz", "valse", "romance", "rondo",
        "fugue", "fantaisie", "fantasia", "variations", "theme", "air", "aria", "march",
        "marche", "dance", "danse", "trio", "quartet", "quintet", "symphony", "symphonie",
        "opera", "ballet", "piece", "pieces", "prelude", "cello", "violoncelle", "violin",
        "violon", "piano", "viola", "alto", "bass", "basson", "flute", "clarinet",
        "allegra", "appassionato", "appasionato", "amoroso", "cantabile", "dolce", "vivace",
        "grave", "lento", "moderato", "adagietto", "andantino", "maestoso"
    ]

    init() {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = base?.appendingPathComponent("OpenCello", isDirectory: true)
        if let directory {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        cacheURL = directory?.appendingPathComponent("imslp_composers.json")
    }

    // MARK: Recherche

    func searchWorks(query: String, limit: Int = 30) async throws -> IMSLPSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return IMSLPSearchOutcome(works: [], composerSurname: nil, usedFallback: false)
        }

        let cacheKey = Self.normalize(trimmed)
        if let cached = cachedOutcome(for: cacheKey) {
            return cached
        }

        let entries = composerSnapshot()
        let queryTokens = Self.tokens(trimmed)
        let match = Self.detectComposer(queryTokens: queryTokens, entries: entries)
        let workTokens = queryTokens.filter { token in
            !Self.stopwords.contains(token) && !(match?.matchedTokens.contains(token) ?? false)
        }
        let scoringGroups = workTokens.map { Self.scoringGroup(for: $0) }
        let originalPhrase = workTokens.joined(separator: " ")
        let correctedPhrase = Self.correctedWorkTokens(workTokens).joined(separator: " ")

        let queries = Self.queryPlan(
            raw: trimmed,
            workTokens: workTokens,
            composerSurname: match?.surname
        )

        var scored: [ScoredWork] = []
        var seen = Set<String>()
        var order = 0
        var requestCount = 0
        var lastError: Error?
        var usedFallback = false

        for (queryIndex, candidate) in queries.enumerated() where requestCount < 7 {
            requestCount += 1
            do {
                let works = try await fetchSearch(candidate, limit: 50)
                lastError = nil
                if queryIndex > 0, !works.isEmpty {
                    usedFallback = true
                }
                for work in works {
                    let key = Self.dedupeKey(work.title)
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    let values = Self.scoreValues(
                        work: work,
                        scoringGroups: scoringGroups,
                        originalPhrase: originalPhrase,
                        correctedPhrase: correctedPhrase,
                        composerSurname: match?.surname
                    )
                    scored.append(
                        ScoredWork(
                            work: work,
                            score: values.total,
                            workScore: values.work,
                            order: order
                        )
                    )
                    order += 1
                }
            } catch {
                lastError = error
            }

            let strong = scored.filter { $0.score >= 10 }.count
            if strong >= 2 {
                break
            }
        }

        if scored.isEmpty, let lastError {
            throw lastError
        }

        let ranked = scored
            .filter { workTokens.isEmpty ? $0.score > 0 : $0.workScore > 0 }
            .sorted {
                $0.score == $1.score ? $0.order < $1.order : $0.score > $1.score
            }

        let outcome = IMSLPSearchOutcome(
            works: Array(ranked.prefix(limit).map(\.work)),
            composerSurname: match?.surname,
            usedFallback: usedFallback
        )
        storeOutcome(outcome, for: cacheKey)
        return outcome
    }

    // MARK: Index des compositeurs

    /// Charge tout l'index (pagines de 1 000) et le met en cache. Peut prendre quelques secondes.
    func loadComposerIndex(forceRefresh: Bool = false) async throws -> [ComposerEntry] {
        if !forceRefresh, let cached = readCachedComposers(), !cached.isEmpty {
            let entries = cached.map(Self.entry(for:))
            setIndex(entries)
            return entries
        }

        var all: [IMSLPComposer] = []
        var start = 0
        var pages = 0
        var more = true

        while more, pages < 80 {
            let page = try await fetchComposerPage(start: start)
            all.append(contentsOf: page.people)
            more = page.more && !page.people.isEmpty
            start += 1000
            pages += 1
        }

        var unique: [IMSLPComposer] = []
        var seen = Set<String>()
        for composer in all where !seen.contains(composer.id) {
            seen.insert(composer.id)
            unique.append(composer)
        }

        if let cacheURL, let encoded = try? JSONEncoder().encode(unique) {
            try? encoded.write(to: cacheURL)
        }

        let entries = unique.map(Self.entry(for:))
        setIndex(entries)
        return entries
    }

    /// Lance le chargement de l'index en arrière-plan (sans bloquer l'interface).
    func preloadComposers() {
        lock.lock()
        if loadingComposers || !index.isEmpty {
            lock.unlock()
            return
        }
        loadingComposers = true
        lock.unlock()

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            defer { self.setLoadingComposers(false) }
            _ = try? await self.loadComposerIndex()
        }
    }

    private func setLoadingComposers(_ value: Bool) {
        lock.lock()
        loadingComposers = value
        lock.unlock()
    }

    var composerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return index.count
    }

    /// Exposé pour les tests : plan de requêtes calculé pour une saisie.
    func debugPlan(for query: String) -> [String] {
        let entries = composerSnapshot()
        let queryTokens = Self.tokens(query)
        let match = Self.detectComposer(queryTokens: queryTokens, entries: entries)
        let workTokens = queryTokens.filter { token in
            !Self.stopwords.contains(token) && !(match?.matchedTokens.contains(token) ?? false)
        }
        let plan = Self.queryPlan(raw: query, workTokens: workTokens, composerSurname: match?.surname)
        return [
            "composer=\(match?.surname ?? "-")",
            "workTokens=\(workTokens.joined(separator: ","))"
        ] + plan
    }

    private func composerSnapshot() -> [ComposerEntry] {
        lock.lock()
        defer { lock.unlock() }
        return index
    }

    private func setIndex(_ entries: [ComposerEntry]) {
        lock.lock()
        index = entries
        lock.unlock()
    }

    private func readCachedComposers() -> [IMSLPComposer]? {
        guard let cacheURL,
              let data = try? Data(contentsOf: cacheURL),
              let composers = try? JSONDecoder().decode([IMSLPComposer].self, from: data) else {
            return nil
        }
        return composers
    }

    // MARK: Pagination API ISCR

    private func fetchComposerPage(start: Int) async throws -> (people: [IMSLPComposer], more: Bool) {
        let urlString = "https://imslp.org/imslpscripts/API.ISCR.php?account=worklist/disclaimer=accepted/sort=id/type=1/start=\(start)/retformat=json"
        guard let url = URL(string: urlString) else { throw IMSLPError.http }
        let data = try await fetch(url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IMSLPError.decoding
        }
        let metadata = json["metadata"] as? [String: Any]
        let more = metadata?["moreresultsavailable"] as? Bool ?? false

        var people: [IMSLPComposer] = []
        for (key, value) in json where key != "metadata" {
            guard let dictionary = value as? [String: Any],
                  let id = dictionary["id"] as? String,
                  id.hasPrefix("Category:") else { continue }
            let name = id
                .replacingOccurrences(of: "Category:", with: "")
                .replacingOccurrences(of: "_", with: " ")
            guard !name.contains("/") else { continue }
            people.append(
                IMSLPComposer(
                    id: id,
                    name: name,
                    permlink: dictionary["permlink"] as? String
                )
            )
        }
        return (people, more)
    }

    // MARK: Requêtes

    private func fetchSearch(_ query: String, limit: Int) async throws -> [IMSLPWork] {
        var components = URLComponents(string: "https://imslp.org/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srnamespace", value: "0"),
            URLQueryItem(name: "srlimit", value: "\(min(max(limit, 1), 50))"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { throw IMSLPError.http }
        let data = try await fetch(url)
        do {
            let envelope = try JSONDecoder().decode(IMSLPSearchEnvelope.self, from: data)
            return envelope.query?.search ?? []
        } catch {
            throw IMSLPError.decoding
        }
    }

    private func fetch(_ url: URL, session: URLSession = .shared, timeout: TimeInterval = 25, cookieHeader: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        if let cookieHeader {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IMSLPError.http
        }
        return data
    }

    // MARK: Fichiers de partitions (PDF)

    /// Session dédiée au téléchargement, avec l'en-tête `Cookie` posé
    /// manuellement (déterministe ; la sémantique de stockage d'URLSession
    /// n'envoie pas toujours les cookies posés à froid).
    ///
    /// Deux cookies traversent les écrans anti-robot d'IMSLP :
    /// - `imslpdisclaimeraccepted=yes` : acceptation du disclaimer de copyright ;
    /// - `redirectPassed=1` : normalement posé par le JavaScript de
    ///   l'interstitiel IMSLP ; posé d'emblée, la page de téléchargement
    ///   (« Subscribe / sm_dl_wait ») est servie directement par le serveur.
    private static let downloadCookieHeader = "imslpdisclaimeraccepted=yes; redirectPassed=1"

    private static let downloadSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    /// Liste les PDF d'une page d'œuvre IMSLP : métadonnées et statut de
    /// copyright tirés du wikitext (blocs `{{#fte:imslpfile …}}`), index de
    /// téléchargement repéré dans le HTML rendu de la page.
    func listScoreFiles(pageTitle: String) async throws -> [IMSLPScoreFile] {
        var components = URLComponents(string: "https://imslp.org/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "parse"),
            URLQueryItem(name: "page", value: pageTitle),
            URLQueryItem(name: "prop", value: "wikitext"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let wikitextURL = components?.url else { throw IMSLPError.http }
        let wikitextData = try await fetch(wikitextURL)
        struct WikitextEnvelope: Decodable {
            struct Parse: Decodable {
                struct Wikitext: Decodable {
                    let text: String
                    enum CodingKeys: String, CodingKey { case text = "*" }
                }
                let wikitext: Wikitext
            }
            let parse: Parse
        }
        guard let envelope = try? JSONDecoder().decode(WikitextEnvelope.self, from: wikitextData) else {
            throw IMSLPError.decoding
        }

        guard let page = pageURL(for: pageTitle) else { throw IMSLPError.http }
        let htmlData = try await fetch(page, session: Self.downloadSession, timeout: 60, cookieHeader: Self.downloadCookieHeader)
        let html = String(decoding: htmlData, as: UTF8.self)

        return Self.scoreFiles(fromWikitext: envelope.parse.wikitext.text, html: html)
    }

    /// Télécharge le PDF d'un fichier IMSLP identifié par son index
    /// (`Special:ImagefromIndex`, fourni par `listScoreFiles`).
    ///
    /// IMSLP sert le fichier en deux temps : la page de téléchargement expose
    /// l'URL réelle (miroir) dans l'attribut `data-id` du span `#sm_dl_wait`.
    func downloadScoreFile(index: Int) async throws -> Data {
        guard let page = URL(string: "https://imslp.org/wiki/Special:ImagefromIndex/\(index)") else {
            throw IMSLPError.http
        }
        let data = try await fetch(page, session: Self.downloadSession, timeout: 60, cookieHeader: Self.downloadCookieHeader)
        let html = String(decoding: data, as: UTF8.self)
        guard let fileURL = Self.downloadURL(fromDownloadPage: html) else {
            throw IMSLPError.fileUnavailable
        }
        let pdf = try await fetch(fileURL, session: Self.downloadSession, timeout: 300, cookieHeader: Self.downloadCookieHeader)
        guard String(decoding: pdf.prefix(4), as: UTF8.self) == "%PDF" else {
            throw IMSLPError.notAPDF
        }
        return pdf
    }

    /// Extrait l'URL du fichier (miroir) depuis la page de téléchargement
    /// IMSLP (`<span id="sm_dl_wait" data-id="https&#58;//…">`).
    /// Exposé (internal) pour les tests CLI.
    static func downloadURL(fromDownloadPage html: String) -> URL? {
        guard let span = html.range(of: "id=\"sm_dl_wait\"") else { return nil }
        let tail = String(html[span.upperBound...])
        guard let attribute = tail.range(of: "data-id=\"") else { return nil }
        let rest = String(tail[attribute.upperBound...])
        guard let end = rest.range(of: "\"") else { return nil }
        let encoded = String(rest[rest.startIndex..<end.lowerBound])
        let decoded = encoded
            .replacingOccurrences(of: "&#58;", with: ":")
            .replacingOccurrences(of: "&#47;", with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: decoded)
    }

    /// Analyse les blocs `{{#fte:imslpfile …}}` du wikitext et rapproche chaque
    /// nom de fichier de son index de téléchargement dans le HTML rendu
    /// (occurrence la plus proche du nom de fichier). Exposé pour les tests.
    static func scoreFiles(fromWikitext wikitext: String, html: String) -> [IMSLPScoreFile] {
        var files: [IMSLPScoreFile] = []
        var searchRange = wikitext.startIndex..<wikitext.endIndex
        while let start = wikitext.range(of: "{{#fte:imslpfile", range: searchRange) {
            guard let end = wikitext.range(of: "\n}}", range: start.upperBound..<wikitext.endIndex)?.lowerBound else {
                break
            }
            let block = String(wikitext[start.upperBound..<end])
            if let file = scoreFile(fromBlock: block, html: html) {
                files.append(file)
            }
            if end >= wikitext.endIndex { break }
            searchRange = end..<wikitext.endIndex
        }
        return files
    }

    private static func scoreFile(fromBlock block: String, html: String) -> IMSLPScoreFile? {
        var name: String?
        var description: String?
        var copyright: String?
        for line in block.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { continue }
            let field = trimmed.dropFirst()
            guard let separator = field.firstIndex(of: "=") else { continue }
            var key = String(field[..<separator]).trimmingCharacters(in: .whitespaces)
            // « File Name 1 » → « File Name » : on retire les chiffres finaux.
            while let last = key.last, last.isNumber {
                key.removeLast()
            }
            key = key.trimmingCharacters(in: .whitespaces)
            let value = String(field[field.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            switch key {
            case "File Name": name = value
            case "File Description": description = value
            case "Copyright": copyright = value
            default: break
            }
        }
        guard let name, name.lowercased().hasSuffix(".pdf") else { return nil }
        return IMSLPScoreFile(
            name: name,
            description: description ?? "",
            copyright: copyright ?? "",
            index: downloadIndex(for: name, in: html)
        )
    }

    /// Index de téléchargement d'un fichier : le lien `ImagefromIndex`
    /// le plus proche du nom dans le HTML rendu (heuristique vérifiée).
    private static func downloadIndex(for fileName: String, in html: String) -> Int? {
        guard let position = html.range(of: fileName) else { return nil }
        let lower = html.index(position.lowerBound, offsetBy: -2500, limitedBy: html.startIndex) ?? html.startIndex
        let upper = html.index(position.upperBound, offsetBy: 500, limitedBy: html.endIndex) ?? html.endIndex
        let window = String(html[lower..<upper])

        var found: Int?
        var cursor = window.startIndex
        while let match = window.range(of: "ImagefromIndex/", range: cursor..<window.endIndex) {
            let digitsStart = match.upperBound
            var digitsEnd = digitsStart
            while digitsEnd < window.endIndex, window[digitsEnd].isNumber {
                digitsEnd = window.index(after: digitsEnd)
            }
            if digitsEnd > digitsStart, let value = Int(window[digitsStart..<digitsEnd]) {
                found = value
            }
            cursor = match.upperBound
        }
        return found
    }

    func pageURL(for title: String) -> URL? {
        let underscored = title.replacingOccurrences(of: " ", with: "_")
        guard let encoded = underscored.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "https://imslp.org/wiki/\(encoded)")
    }

    // MARK: Détection du compositeur

    private struct ComposerMatch {
        let surname: String
        let matchedTokens: Set<String>
    }

    private static func detectComposer(queryTokens: [String], entries: [ComposerEntry]) -> ComposerMatch? {
        guard !entries.isEmpty else { return nil }

        let ignoredTokens = Set(queryTokens.filter { token in
            if musicalTerms.contains(token) || TitleVocabulary.core.contains(token) {
                return true
            }
            if let corrected = vocabularyCorrection(for: token), TitleVocabulary.core.contains(corrected) {
                return true
            }
            return false
        })

        var best: (entry: ComposerEntry, score: Double, matched: Set<String>)?

        for entry in entries {
            var score = 0.0
            var matched = Set<String>()
            var surnameMatches = 0

            for token in queryTokens where !stopwords.contains(token) && !ignoredTokens.contains(token) {
                if entry.surnameTokens.contains(token) {
                    score += 3
                    matched.insert(token)
                    surnameMatches += 1
                } else if token.count >= 5,
                          entry.surnameTokens.contains(where: { levenshtein(token, $0) <= 1 }) {
                    score += 1.5
                    matched.insert(token)
                    surnameMatches += 1
                } else if entry.givenTokens.contains(token) {
                    score += 0.5
                    matched.insert(token)
                }
            }

            guard surnameMatches > 0 else { continue }
            score += min(2.0, Double(surnameMatches) / Double(max(1, entry.surnameTokens.count)) * 2.0)

            if score > (best?.score ?? 0) {
                best = (entry, score, matched)
            }
        }

        guard let best, best.score >= 3 else { return nil }

        let surnameNormalized = normalize(best.entry.composer.surname)
        guard !musicalTerms.contains(surnameNormalized),
              !TitleVocabulary.core.contains(surnameNormalized) else { return nil }

        return ComposerMatch(surname: best.entry.composer.surname, matchedTokens: best.matched)
    }

    private static func entry(for composer: IMSLPComposer) -> ComposerEntry {
        let parts = composer.name.split(separator: ",", maxSplits: 1).map(String.init)
        let surname = parts.first ?? composer.name
        let given = parts.count > 1 ? parts[1] : ""
        return ComposerEntry(
            composer: composer,
            surnameTokens: tokens(surname),
            givenTokens: tokens(given)
        )
    }

    // MARK: Plan de requêtes

    private static func queryPlan(raw: String, workTokens: [String], composerSurname: String?) -> [String] {
        var queries: [String] = [raw]
        let corrected = correctedWorkTokens(workTokens)

        if let composerSurname {
            if !workTokens.isEmpty {
                queries.append("\(composerSurname) \(workTokens.joined(separator: " "))")
                for variant in correctedQueries(workTokens).prefix(5) {
                    queries.append("\(composerSurname) \(variant)")
                }
            }
            queries.append(composerSurname)
        }

        for variant in correctedQueries(workTokens).prefix(5) {
            queries.append(variant)
        }

        queries.append(contentsOf: hyphenJoinQueries(workTokens))
        queries.append(contentsOf: hyphenJoinQueries(corrected))

        var seen = Set<String>()
        return queries.filter { query in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func correctedWorkTokens(_ tokens: [String]) -> [String] {
        let vocabulary = tokens.map { vocabularyCorrection(for: $0) ?? $0 }
        if vocabulary != tokens {
            return vocabulary
        }

        guard let target = tokens.max(by: { $0.count < $1.count }),
              target.count >= 6,
              let variant = typoVariants(target).first else {
            return tokens
        }
        return tokens.map { $0 == target ? variant : $0 }
    }

    private static func correctedQueries(_ tokens: [String]) -> [String] {
        var result: [String] = []
        let vocabulary = tokens.map { vocabularyCorrection(for: $0) ?? $0 }
        if vocabulary != tokens {
            result.append(vocabulary.joined(separator: " "))
        }

        let base = vocabulary
        guard let target = base.max(by: { $0.count < $1.count }),
              target.count >= 6 else { return result }

        for variant in typoVariantsDeep(target).prefix(5) {
            let replaced = base.map { $0 == target ? variant : $0 }
            let query = replaced.joined(separator: " ")
            if !result.contains(query) {
                result.append(query)
            }
        }
        return result
    }

    /// Correction par lexique hybride : lexique musical noyau + vocabulaire IMSLP.
    /// Distance d'édition d'abord ; à distance égale, terme noyau puis fréquence.
    private static func vocabularyCorrection(for token: String) -> String? {
        guard token.count >= 5, token.allSatisfy({ $0.isLetter }) else { return nil }
        if TitleVocabulary.contains(token) { return nil }

        let maxDistance = token.count >= 10 ? 3 : (token.count >= 7 ? 2 : 1)
        var best: (word: String, distance: Int, priority: Int)?

        func consider(_ word: String, priority: Int) {
            guard abs(word.count - token.count) <= maxDistance, word != token else { return }
            let distance = levenshtein(token, word)
            guard distance > 0, distance <= maxDistance else { return }
            if let current = best {
                if distance < current.distance || (distance == current.distance && priority < current.priority) {
                    best = (word, distance, priority)
                }
            } else {
                best = (word, distance, priority)
            }
        }

        for (index, word) in TitleVocabulary.coreList.enumerated() {
            consider(word, priority: index)
        }
        for (index, word) in TitleVocabulary.ranked.enumerated() {
            consider(word, priority: 10_000 + index)
        }
        return best?.word
    }

    private static func scoringGroup(for token: String) -> [String] {
        var group = [token]
        if let corrected = vocabularyCorrection(for: token), !group.contains(corrected) {
            group.append(corrected)
        }
        for variant in typoVariantsDeep(token) where !group.contains(variant) {
            group.append(variant)
        }
        return group
    }

    private static func typoVariantsDeep(_ token: String) -> [String] {
        var variants = typoVariants(token)
        for variant in variants.prefix(2) {
            for second in typoVariants(variant).prefix(2) where !variants.contains(second) {
                variants.append(second)
            }
        }
        return variants
    }

    /// Joint les deux derniers mots par un trait d'union : « saint saens » → « saint-saens ».
    private static func hyphenJoinQueries(_ tokens: [String]) -> [String] {
        guard tokens.count >= 2 else { return [] }
        let last = tokens[tokens.count - 1]
        let previous = tokens[tokens.count - 2]
        guard last.count >= 3, previous.count >= 3 else { return [] }
        var joined = Array(tokens.dropLast(2))
        joined.append("\(previous)-\(last)")
        return [joined.joined(separator: " ")]
    }

    private static func typoVariants(_ token: String) -> [String] {
        guard token.count >= 5, token.allSatisfy({ $0.isLetter }) else { return [] }
        let characters = Array(token)
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var scored: [(String, Int)] = []

        for index in 1..<characters.count {
            let current = characters[index]
            guard !vowels.contains(current) else { continue }

            if characters[index - 1] == current {
                var variant = characters
                variant.remove(at: index)
                scored.append((String(variant), current == "s" ? -1 : -2))
            } else {
                var variant = characters
                variant.insert(current, at: index)
                let bonus: Int
                switch current {
                case "s": bonus = 5
                case "t", "n", "l", "m", "p", "c", "f", "r": bonus = 3
                default: bonus = 1
                }
                scored.append((String(variant), bonus))
            }
        }

        var results: [String] = []
        for (variant, _) in scored.sorted(by: { $0.1 > $1.1 }) where variant != token {
            if !results.contains(variant) {
                results.append(variant)
            }
        }
        return results
    }

    // MARK: Reclassement

    private struct ScoredWork {
        let work: IMSLPWork
        let score: Double
        let workScore: Double
        let order: Int
    }

    private static func scoreValues(
        work: IMSLPWork,
        scoringGroups: [[String]],
        originalPhrase: String,
        correctedPhrase: String,
        composerSurname: String?
    ) -> (total: Double, work: Double) {
        guard !scoringGroups.isEmpty || composerSurname != nil else { return (0, 0) }

        let title = normalize(work.title)
        let titleTokens = title.split(separator: " ").map(String.init)
        var workScore = 0.0

        if !scoringGroups.isEmpty {
            for group in scoringGroups {
                if group.contains(where: { titleTokens.contains($0) }) {
                    workScore += 3
                } else if group.contains(where: { variant in
                    variant.count >= 5 && titleTokens.contains(where: { levenshtein(variant, $0) <= 1 })
                }) {
                    workScore += 1.5
                }
            }

            if title.contains(originalPhrase) {
                workScore += 8
            } else if correctedPhrase != originalPhrase, title.contains(correctedPhrase) {
                workScore += 6
            }
        }

        var composerScore = 0.0
        if let composerSurname {
            let surname = normalize(composerSurname)
            if work.title.contains("(\(composerSurname),") {
                composerScore += 8
            } else if title.contains(surname) {
                composerScore += 4
            }
        }

        return (workScore + composerScore, workScore)
    }

    private static func dedupeKey(_ title: String) -> String {
        normalize(title).replacingOccurrences(of: " ", with: "")
    }

    // MARK: Normalisation

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "ø", with: "o")
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(_ value: String) -> [String] {
        normalize(value).split(separator: " ").map(String.init)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let left = Array(a)
        let right = Array(b)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = [Int](repeating: 0, count: right.count + 1)

        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }

    // MARK: Cache de recherche

    private func cachedOutcome(for key: String) -> IMSLPSearchOutcome? {
        lock.lock()
        defer { lock.unlock() }
        return searchCache[key]
    }

    private func storeOutcome(_ outcome: IMSLPSearchOutcome, for key: String) {
        guard !outcome.works.isEmpty else { return }
        lock.lock()
        if searchCache.count >= 30 {
            searchCache.removeAll()
        }
        searchCache[key] = outcome
        lock.unlock()
    }
}
