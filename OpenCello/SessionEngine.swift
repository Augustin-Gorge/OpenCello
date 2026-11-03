import Foundation
import SwiftUI
import AppKit
import QuartzCore
import Vision

enum AppMode: String, CaseIterable {
    case free = "Séance"
    case piece = "Morceau"
    case exercises = "Exercices"
    case reports = "Rapports"
    case profile = "Profil"
}

enum SessionPhase {
    case idle
    case calibrating
    case running
}

/// Orchestrateur : caméra + micro + règles + rapport.
@MainActor
final class SessionEngine: ObservableObject {
    @Published var phase: SessionPhase = .idle
    @Published var cameraStatus = "Caméra arrêtée"
    @Published var cameraRunning = false
    @Published var micStatus = "Micro arrêté"
    @Published var micRunning = false
    @Published var pitchText = "—"
    @Published var pitchDetail = ""
    @Published var pitchColor: Color = .secondary
    @Published var rms: Double = 0
    @Published var alerts: [ActiveAlert] = []
    @Published var overlayLandmarks: [Landmark] = []
    @Published var baselineStatus = "Baseline posture : non calibrée"
    @Published var livePosture: [LiveRuleStatus] = []
    @Published var message: String?

    // Rapports et navigation
    @Published var selectedReportID: UUID?
    @Published var requestedExerciseID: String?

    // Mode morceau
    @Published var appMode: AppMode = .free
    @Published var imslpQuery = ""
    @Published var imslpResults: [IMSLPWork] = []
    @Published var imslpLoading = false
    @Published var imslpError: String?
    @Published var imslpComposer: String?
    @Published var imslpUsedFallback = false
    @Published var imslpWorkTitle: String?
    @Published var imslpFiles: [IMSLPScoreFile] = []
    @Published var imslpFilesLoading = false
    @Published var imslpFilesError: String?
    @Published var imslpDownloadingIndex: Int?
    @Published var currentPDF: URL?
    @Published var currentMusicXML: URL?
    @Published var omrState: OMRState = .idle
    @Published var scoreURL: URL?
    @Published var score: Score?
    @Published var scoreTitle = ""
    @Published var selectedPartIndex = 0
    @Published var pieceBPM: Double = 100
    @Published var pieceRunning = false
    @Published var pieceFeedback: FollowFeedback?
    @Published var pieceProgress: Double = 0
    @Published var pieceStats: PieceStats?
    @Published var pieceAssignment: PositionAssignment?
    @Published var pieceHandStatus = "Main gauche : non détectée"
    @Published var pieceGlideMs: Double?
    @Published var pieceLastMoment: ReplayMoment?
    @Published var liveReplay: ReplayMoment?
    @Published var lastNote: NoteEvent?
    @Published var lastNoteFeedback: NoteFeedback?
    @Published var recommendedExerciseIDs: [String] = []

    #if DEBUG
    var debugAutoDownloadName: String?
    var debugAutoConvert = false
    #endif

    // Mode profil (archet/cordes)
    @Published var analysisMode: AnalysisMode = .posture
    @Published var bowReference: BowReference?
    @Published var bowCalibrationActive = false
    @Published var bowCalibrationPoints: [CGPoint] = []
    @Published var bowLines: [BowLine] = []
    @Published var bowFeedback: BowEvaluation?
    @Published var bowVector: BowVector?
    @Published var bowAlert: String?
    @Published var lastArticulation: Articulation?

    let settings = AppSettings()
    let progress = ProgressStore()
    let camera = CameraManager()
    let mic = MicrophoneManager()
    let rules = PostureRules()
    let report = SessionReport()

    private var calibrationSamples: [PoseMetrics] = []
    private var lastCalibrationSampleAt: TimeInterval = 0
    private var lastLivePostureAt: TimeInterval = 0
    private var lastPitchTimestamp: TimeInterval = 0
    private var sessionStartAt: Date?
    private var follower: ScoreFollower?
    private var previousNoteEnd: TimeInterval?
    private var previousNoteMidi: Double?
    private var recentNoteStarts: [TimeInterval] = []
    private let motionAnalyzer = MotionAnalyzer()

    // Phase 7 (v1.1) : main gauche, positions, techniques, replays.
    private let leftHandAnalyzer = LeftHandAnalyzer()
    private let bowVectorizer = BowVectorizer()
    private let positionTracker = PositionTracker()
    private let techniqueTracker = TechniqueTracker()
    private var currentHandMetrics: LeftHandMetrics?
    private var currentAssignment: PositionAssignment?
    private var pendingFeedback: FollowFeedback?
    private var pendingGlide: GlideInfo?
    private var pendingGlideVoluntary = false
    private var pitchSamples: [PitchSample] = []
    private var pieceSessionStart: TimeInterval = 0
    private var sessionVideoURL: URL?

    init() {
        camera.onStatus = { [weak self] text in
            Task { @MainActor [weak self] in self?.cameraStatus = text }
        }
        camera.onRunning = { [weak self] running in
            Task { @MainActor [weak self] in self?.cameraRunning = running }
        }
        camera.onPose = { [weak self] frame in
            Task { @MainActor [weak self] in self?.handlePose(frame) }
        }
        mic.onStatus = { [weak self] text in
            Task { @MainActor [weak self] in self?.micStatus = text }
        }
        mic.onRunning = { [weak self] running in
            Task { @MainActor [weak self] in self?.micRunning = running }
        }
        mic.onPitch = { [weak self] frame in
            Task { @MainActor [weak self] in self?.handlePitch(frame) }
        }
        mic.onSegment = { [weak self] output in
            Task { @MainActor [weak self] in self?.handleSegment(output) }
        }
        camera.onBow = { [weak self] frame in
            Task { @MainActor [weak self] in self?.handleBow(frame) }
        }

        IMSLPClient.shared.preloadComposers()
        rules.apply(profile: settings.profile)
        refreshRecommendationsFromHistory()
    }

    func applySettings() {
        rules.apply(profile: settings.profile)
        leftHandAnalyzer.thresholds = PostureRules.handThresholds(for: settings.profile)
    }

    private func refreshRecommendationsFromHistory() {
        guard let last = progress.records.first else {
            recommendedExerciseIDs = ExerciseCatalog.recommendations(for: []).map(\.id)
            return
        }
        var ruleIDs = last.posture
            .sorted { $0.seconds > $1.seconds }
            .filter { $0.seconds > 2 }
            .prefix(3)
            .map(\.ruleID)
        if last.noteCount > 0 {
            if last.meanAbsCents > settings.intonationTolerance { ruleIDs.append("B1") }
            if last.meanStability > settings.stabilityTolerance { ruleIDs.append("B2") }
            if let hnr = last.meanHNR, hnr < 18 { ruleIDs.append("B7") }
        }
        recommendedExerciseIDs = ExerciseCatalog.recommendations(for: ruleIDs).map(\.id)
    }

    var elapsedText: String {
        guard let sessionStartAt, phase == .running else { return "00:00" }
        let elapsed = Int(Date().timeIntervalSince(sessionStartAt))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    func startCalibration() {
        message = nil
        calibrationSamples = []
        lastCalibrationSampleAt = 0
        analysisMode = .posture
        camera.analysisMode = .posture
        rules.apply(profile: settings.profile)
        phase = .calibrating
        camera.start()
        baselineStatus = "Calibration en cours — gardez une position de jeu neutre"
    }

    func cancelCalibration() {
        phase = .idle
        calibrationSamples = []
        camera.stop()
        baselineStatus = rules.baseline == nil ? "Baseline posture : non calibrée" : "Baseline posture : calibrée"
    }

    func startSession() {
        message = nil
        rules.apply(profile: settings.profile)
        rules.reset()
        alerts = []
        report.reset(startedAt: Date())
        sessionStartAt = Date()
        lastPitchTimestamp = 0
        lastNoteFeedback = nil
        bowAlert = nil
        previousNoteEnd = nil
        previousNoteMidi = nil
        recentNoteStarts = []
        lastArticulation = nil
        motionAnalyzer.reset()
        bowVectorizer.reset()
        bowVector = nil
        leftHandAnalyzer.thresholds = PostureRules.handThresholds(for: settings.profile)
        leftHandAnalyzer.reset()
        positionTracker.reset()
        techniqueTracker.reset()
        currentHandMetrics = nil
        currentAssignment = nil
        pendingFeedback = nil
        pendingGlide = nil
        pendingGlideVoluntary = false
        pitchSamples = []
        phase = .running
        camera.analysisMode = analysisMode
        camera.start()
        if settings.recordSessionVideo, let url = SessionVideoStore.makeURL() {
            sessionVideoURL = url
            camera.startRecording(to: url)
        } else {
            sessionVideoURL = nil
        }
        mic.start()
    }

    func stopSession() {
        guard phase == .running else { return }
        camera.stop()
        mic.stop()
        cameraRunning = false
        micRunning = false
        report.endedAt = Date()
        if let metrics = motionAnalyzer.metrics() {
            report.motionJerk = metrics.jerk
            report.motionStillness = metrics.stillness
            report.motionSamples = metrics.samples
        }
        let summary = rules.summary()

        let positionStats = makePositionStats()
        let technique = techniqueTracker.record()
        let hand = report.handRecord()
        let duration = sessionStartAt.map { Date().timeIntervalSince($0) } ?? 0
        let record = SessionRecord(
            id: UUID(),
            date: sessionStartAt ?? Date(),
            mode: "Séance libre",
            title: "Séance libre",
            duration: duration,
            posture: summary.map {
                PostureRecord(
                    ruleID: $0.id,
                    title: $0.title,
                    seconds: $0.totalBadSeconds,
                    occurrences: $0.occurrences
                )
            },
            noteCount: report.noteCount,
            inTuneNotes: report.inTuneNotes,
            meanAbsCents: report.meanAbsCents,
            meanStability: report.meanStability,
            soundingSeconds: report.soundingSeconds,
            noteCents: report.noteCents,
            noteStability: report.noteStability,
            piece: nil,
            bow: report.bowRecord(),
            meanHNR: report.meanHNR,
            meanCentroid: report.meanCentroid,
            meanRMSVariation: report.meanRMSVariation,
            postureDetectionRate: report.detectionRate,
            medianFrequency: report.medianFrequency,
            validPitchFrames: report.validPitchFrames,
            pitchFrames: report.pitchFrames,
            articulationCounts: report.articulationCounts.isEmpty ? nil : report.articulationCounts,
            meanVibratoRate: report.meanVibratoRate,
            meanVibratoExtent: report.meanVibratoExtent,
            hand: hand,
            positionStats: positionStats,
            technique: technique,
            videoPath: sessionVideoURL?.path
        )
        progress.add(record)
        refreshRecommendationsFromHistory()

        resetSessionUI()
        selectedReportID = record.id
        appMode = .reports
    }

    /// Remet l'interface de la séance à zéro (après arrêt ou changement de mode).
    private func resetSessionUI() {
        phase = .idle
        alerts = []
        livePosture = []
        overlayLandmarks = []
        pitchText = "—"
        pitchDetail = ""
        pitchColor = .secondary
        rms = 0
        lastNoteFeedback = nil
        bowFeedback = nil
        bowVector = nil
        bowAlert = nil
    }

    /// Ouvre un rapport précis dans l'onglet Rapports (depuis le profil, etc.).
    func openReportInHistory(_ id: UUID) {
        selectedReportID = id
        appMode = .reports
    }

    /// Ouvre la fiche d'un exercice depuis un rapport.
    func openExercise(_ id: String) {
        requestedExerciseID = id
        switchMode(to: .exercises)
    }

    // MARK: - Mode profil (archet/cordes)

    func setAnalysisMode(_ mode: AnalysisMode) {
        guard phase == .idle, !pieceRunning else { return }
        analysisMode = mode
        camera.analysisMode = mode
        bowFeedback = nil
        bowVector = nil
        bowAlert = nil
        bowLines = []
        if mode == .bow {
            camera.start()
        } else {
            camera.stop()
        }
    }

    func startBowCalibration() {
        guard phase == .idle else { return }
        analysisMode = .bow
        camera.analysisMode = .bow
        bowReference = nil
        bowCalibrationPoints = []
        bowCalibrationActive = true
        bowFeedback = nil
        bowVector = nil
        bowAlert = nil
        bowVectorizer.reset()
        camera.start()
    }

    func addBowCalibrationPoint(_ point: CGPoint) {
        guard bowCalibrationActive else { return }
        let clamped = CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
        bowCalibrationPoints.append(clamped)
        if bowCalibrationPoints.count == 2 {
            bowReference = BowReference(
                bridge: bowCalibrationPoints[0],
                fingerboard: bowCalibrationPoints[1]
            )
            bowCalibrationActive = false
            bowCalibrationPoints = []
            message = "Profil calibré : chevalet et bout de la touche enregistrés."
        }
    }

    private func handleBow(_ frame: ProfileFrame?) {
        guard analysisMode == .bow else { return }

        guard let frame else {
            bowLines = []
            bowFeedback = nil
            if !bowCalibrationActive {
                bowAlert = "Caméra indisponible"
            }
            return
        }

        bowLines = frame.lines.compactMap { line in
            guard let segment = LineDetector.segment(
                for: line,
                width: 320,
                height: 180
            ) else { return nil }
            return BowLine(
                start: CGPoint(x: segment.0.x / 320, y: segment.0.y / 180),
                end: CGPoint(x: segment.1.x / 320, y: segment.1.y / 180)
            )
        }

        guard !bowCalibrationActive, let reference = bowReference else {
            bowFeedback = nil
            return
        }

        guard let evaluation = BowGeometry.evaluate(
            lines: frame.lines,
            reference: reference,
            imageSize: CGSize(width: 320, height: 180),
            angleTolerance: 10
        ) else {
            bowFeedback = nil
            bowVector = nil
            bowAlert = "Archet non détecté — cadrez de profil"
            return
        }

        let vector = bowVectorizer.update(evaluation, timestamp: frame.timestamp)
        bowFeedback = evaluation
        bowVector = vector
        if phase == .running {
            report.addBow(evaluation, vector: vector, directionChanges: bowVectorizer.directionChanges)
        }

        if !evaluation.angleOK {
            bowAlert = "Archet non perpendiculaire (\(Int(evaluation.angleDeviation.rounded()))°)"
        } else if !evaluation.zoneOK {
            bowAlert = evaluation.contact < 0.1 ? "Trop près du chevalet" : "Trop près de la touche"
        } else {
            bowAlert = nil
        }
    }

    // MARK: - Mode morceau

    func switchMode(to mode: AppMode) {
        if phase == .running { stopSession() }
        if phase == .calibrating { cancelCalibration() }
        if pieceRunning { stopPieceSession() }
        appMode = mode
        if mode == .piece {
            camera.stop()
        }
    }

    func searchIMSLP() {
        let query = imslpQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        imslpLoading = true
        imslpError = nil
        Task {
            do {
                let outcome = try await IMSLPClient.shared.searchWorks(query: query)
                self.imslpResults = outcome.works
                self.imslpComposer = outcome.composerSurname
                self.imslpUsedFallback = outcome.usedFallback
                self.imslpLoading = false
                if outcome.works.isEmpty {
                    self.imslpError = "Aucun résultat. Essayez le compositeur seul ou un titre plus court."
                }
            } catch {
                self.imslpError = error.localizedDescription
                self.imslpLoading = false
            }
        }
    }

    func openIMSLPPage(for work: IMSLPWork) {
        guard let url = IMSLPClient.shared.pageURL(for: work.title) else { return }
        NSWorkspace.shared.open(url)
    }

    func selectIMSLPTitle(_ work: IMSLPWork) {
        scoreTitle = work.title
        imslpWorkTitle = work.title
        imslpFiles = []
        imslpFilesError = nil
        imslpDownloadingIndex = nil
        currentPDF = nil
        currentMusicXML = nil
        scoreURL = nil
        omrState = .idle
        score = nil
        pieceFeedback = nil
        pieceStats = nil
        pieceProgress = 0
        message = "Titre retenu : \(work.title). Chargement des fichiers PDF…"
        Task { await loadIMSLPFiles(title: work.title) }
    }

    func loadIMSLPFiles(title: String) async {
        imslpFilesLoading = true
        imslpFilesError = nil
        do {
            let files = try await IMSLPClient.shared.listScoreFiles(pageTitle: title)
            imslpFiles = files.sorted { a, b in
                if a.isPublicDomain != b.isPublicDomain {
                    return a.isPublicDomain
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            if files.isEmpty {
                imslpFilesError = "Aucun PDF n'est listé sur cette page IMSLP."
            } else {
                message = "\(files.count) fichier(s) PDF listé(s) — "
                    + "privilégiez les éditions « Domaine public »."
            }
            #if DEBUG
            if let name = debugAutoDownloadName,
               let file = imslpFiles.first(where: { $0.name == name }) {
                debugAutoDownloadName = nil
                downloadIMSLPFile(file)
            }
            #endif
        } catch {
            imslpFiles = []
            imslpFilesError = "Liste des PDF indisponible : \(error.localizedDescription)"
        }
        imslpFilesLoading = false
    }

    func downloadIMSLPFile(_ file: IMSLPScoreFile) {
        guard let index = file.index else {
            message = "Ce fichier n'a pas d'index de téléchargement IMSLP."
            return
        }
        guard let workTitle = imslpWorkTitle else {
            message = "Sélectionnez d'abord une œuvre IMSLP."
            return
        }

        // Un PDF déjà présent n'est pas retéléchargé (IMSLP peut être
        // momentanément indisponible) : on réutilise le fichier local.
        let cached = ScoreLibrary.pdfURL(workTitle: workTitle, fileName: file.name)
        if FileManager.default.fileExists(atPath: cached.path) {
            adoptPDF(cached, fileName: file.name)
            return
        }

        imslpDownloadingIndex = index
        message = "Téléchargement de \(file.name)…"
        Task {
            do {
                let data = try await IMSLPClient.shared.downloadScoreFile(index: index)
                let pdf = try ScoreLibrary.storePDF(
                    data: data,
                    workTitle: workTitle,
                    fileName: file.name
                )
                adoptPDF(pdf, fileName: file.name)
            } catch {
                message = "Téléchargement impossible : \(error.localizedDescription)"
            }
            imslpDownloadingIndex = nil
        }
    }

    private func adoptPDF(_ pdf: URL, fileName: String) {
        currentPDF = pdf
        currentMusicXML = ScoreLibrary.existingMusicXML(for: pdf)
        if let xml = currentMusicXML {
            importScore(from: xml)
            omrState = .ready(xml)
            message = "PDF disponible ; MusicXML déjà présent et chargé."
        } else {
            omrState = .idle
            message = "PDF disponible (\(fileName)). Conversion en MusicXML possible."
            #if DEBUG
            if debugAutoConvert {
                debugAutoConvert = false
                convertCurrentPDF()
            }
            #endif
        }
    }

    func importPDF(from url: URL) {
        do {
            let title = url.deletingPathExtension().lastPathComponent
            let pdf = try ScoreLibrary.importPDF(from: url, workTitle: title)
            currentPDF = pdf
            imslpWorkTitle = title
            currentMusicXML = ScoreLibrary.existingMusicXML(for: pdf)
            if let xml = currentMusicXML {
                importScore(from: xml)
                omrState = .ready(xml)
                message = "PDF importé ; MusicXML déjà présent et chargé."
            } else {
                score = nil
                scoreURL = nil
                omrState = .idle
                message = "PDF importé. Utilisez « Convertir en MusicXML » pour lancer Audiveris."
            }
        } catch {
            message = "Import du PDF impossible : \(error.localizedDescription)"
        }
    }

    func convertCurrentPDF(force: Bool = false) {
        guard let pdf = currentPDF else {
            message = "Aucun PDF sélectionné."
            return
        }
        if let existing = ScoreLibrary.existingMusicXML(for: pdf), !force {
            currentMusicXML = existing
            importScore(from: existing)
            omrState = .ready(existing)
            message = "MusicXML déjà présent : ouvert sans reconversion."
            return
        }
        omrState = .running("Conversion en cours avec Audiveris…")
        message = nil
        Task {
            do {
                let target = ScoreLibrary.musicXMLURL(for: pdf)
                _ = try await ScoreOMR.shared.convert(pdf: pdf, musicXML: target)
                currentMusicXML = target
                importScore(from: target)
                omrState = .ready(target)
                message = "MusicXML créé : \(target.lastPathComponent)"
            } catch let omr as OMRServiceError {
                if case .cancelled = omr {
                    omrState = .idle
                    message = "Conversion annulée."
                } else {
                    omrState = .failed(omr.localizedDescription)
                    message = omr.localizedDescription
                }
            } catch {
                omrState = .failed(error.localizedDescription)
                message = error.localizedDescription
            }
        }
    }

    func cancelOMR() {
        ScoreOMR.shared.cancel()
        omrState = .idle
        message = "Annulation demandée."
    }

    /// Import utilisateur d'un MusicXML : copie d'abord dans la bibliothèque
    /// de l'app (accès en écriture durable), puis chargement pour le suivi.
    func importMusicXML(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let title = url.deletingPathExtension().lastPathComponent
            let destination = try ScoreLibrary.storeMusicXML(
                data: data,
                workTitle: title,
                fileName: url.lastPathComponent
            )
            imslpWorkTitle = title
            currentPDF = nil
            importScore(from: destination)
        } catch {
            message = "Import du MusicXML impossible : \(error.localizedDescription)"
        }
    }

    func importScore(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try MusicXMLParser.parse(data: data)
            score = parsed
            scoreURL = url
            currentMusicXML = url
            if !parsed.title.isEmpty {
                scoreTitle = parsed.title
            } else if scoreTitle.isEmpty {
                scoreTitle = url.deletingPathExtension().lastPathComponent
            }
            let siblingPDF = url.deletingPathExtension().appendingPathExtension("pdf")
            if FileManager.default.fileExists(atPath: siblingPDF.path) {
                currentPDF = siblingPDF
            }
            selectedPartIndex = parsed.defaultPartIndex
            if let tempo = parsed.tempo { pieceBPM = tempo }
            pieceFeedback = nil
            pieceStats = nil
            pieceProgress = 0
            message = "Partition chargée : \(scoreTitle)"
        } catch {
            message = "Impossible de lire la partition : \(error.localizedDescription)"
        }
    }

    /// Applique un MusicXML réécrit par MuseScore (ou un autre éditeur) au
    /// suivi en cours, sans toucher au fichier.
    func applyEditedScore(_ parsed: Score) {
        score = parsed
        if !parsed.title.isEmpty { scoreTitle = parsed.title }
        selectedPartIndex = min(selectedPartIndex, max(0, parsed.parts.count - 1))
        if let tempo = parsed.tempo { pieceBPM = tempo }
        pieceFeedback = nil
        pieceStats = nil
        pieceProgress = 0
        message = "Partition mise à jour depuis MuseScore."
    }

    func loadDemoScore() {
        let sequence: [Int] = [36, 38, 40, 41, 43, 45, 47, 48, 50, 52, 53, 55, 57, 59, 60]
        let notes = sequence.enumerated().map { index, midi in
            ScoreNote(
                midi: midi,
                onsetBeats: Double(index),
                durationBeats: 0.9,
                measureIndex: index / 4 + 1
            )
        }
        score = Score(
            title: "Gamme de do majeur (démo)",
            composer: "OpenCello",
            tempo: 80,
            parts: [ScorePart(name: "Violoncelle", notes: notes)]
        )
        scoreTitle = "Gamme de do majeur (démo)"
        selectedPartIndex = 0
        pieceBPM = 80
        pieceFeedback = nil
        pieceStats = nil
        pieceProgress = 0
        message = "Partition de démonstration chargée."
    }

    func startPieceSession() {
        guard let score else {
            message = "Importez d'abord une partition MusicXML (ou chargez la démo)."
            return
        }
        guard score.parts.indices.contains(selectedPartIndex),
              !score.parts[selectedPartIndex].notes.isEmpty else {
            message = "Cette partie ne contient pas de notes."
            return
        }

        camera.analysisMode = .posture
        camera.start()
        if settings.recordSessionVideo, let url = SessionVideoStore.makeURL() {
            sessionVideoURL = url
            camera.startRecording(to: url)
        } else {
            sessionVideoURL = nil
        }
        report.reset(startedAt: Date())
        leftHandAnalyzer.thresholds = PostureRules.handThresholds(for: settings.profile)
        leftHandAnalyzer.reset()
        positionTracker.reset()
        techniqueTracker.reset()
        currentHandMetrics = nil
        currentAssignment = nil
        pendingFeedback = nil
        pendingGlide = nil
        pendingGlideVoluntary = false
        pitchSamples = []
        pieceSessionStart = CACurrentMediaTime()
        pieceAssignment = nil
        pieceHandStatus = "Main gauche : non détectée"
        pieceGlideMs = nil
        pieceLastMoment = nil
        liveReplay = nil
        let newFollower = ScoreFollower(score: score, partIndex: selectedPartIndex, bpm: pieceBPM)
        follower = newFollower
        pieceFeedback = nil
        pieceStats = newFollower.stats
        pieceProgress = 0
        pieceRunning = true
        mic.start()
    }

    func stopPieceSession() {
        guard pieceRunning else { return }
        pieceRunning = false
        mic.stop()
        camera.stop()
        cameraRunning = false

        if let follower {
            pieceStats = follower.stats
            report.endedAt = Date()

            let duration = follower.stats.startedAt.map { Date().timeIntervalSince($0) } ?? 0
            let piece = PieceRecord(
                title: scoreTitle.isEmpty ? "Morceau" : scoreTitle,
                matched: follower.stats.matched,
                total: follower.stats.totalNotes,
                inTune: follower.stats.inTune,
                meanAbsCents: follower.stats.meanAbsCents,
                meanAbsRhythmMs: follower.stats.meanAbsRhythmMs,
                outOfScore: follower.stats.outOfScore,
                estimatedTempo: follower.stats.estimatedTempo
            )
            let positionStats = makePositionStats()
            let technique = techniqueTracker.record()
            let hand = report.handRecord()
            let replays = ReplayBuilder.moments(from: report.positionSamples, technique: technique)
            let record = SessionRecord(
                id: UUID(),
                date: follower.stats.startedAt ?? Date(),
                mode: "Morceau",
                title: piece.title,
                duration: duration,
                posture: [],
                noteCount: follower.stats.matched,
                inTuneNotes: follower.stats.inTune,
                meanAbsCents: follower.stats.meanAbsCents,
                meanStability: 0,
                soundingSeconds: 0,
                noteCents: [],
                noteStability: [],
                piece: piece,
                postureDetectionRate: report.detectionRate,
                hand: hand,
                positionStats: positionStats,
                technique: technique,
                replayMoments: replays.isEmpty ? nil : replays,
                videoPath: sessionVideoURL?.path
            )
            progress.add(record)
            refreshRecommendationsFromHistory()
            selectedReportID = record.id
            appMode = .reports
        }

        pieceFeedback = nil
        pieceAssignment = nil
        pieceGlideMs = nil
        pieceLastMoment = nil
        liveReplay = nil
        follower = nil
        positionTracker.reset()
        techniqueTracker.reset()
        leftHandAnalyzer.reset()
        currentHandMetrics = nil
        currentAssignment = nil
        pendingFeedback = nil
        pendingGlide = nil
        pendingGlideVoluntary = false
        pitchSamples = []
    }

    /// Agrège les notes de la séance en statistiques de position.
    private func makePositionStats() -> PositionStatsRecord? {
        let samples = report.positionSamples
        guard !samples.isEmpty else { return nil }
        let shifts = samples.filter(\.isShift)
        let arrivals = shifts.compactMap(\.cents)
        return PositionStatsRecord(
            samples: samples,
            shiftCount: shifts.count,
            meanArrivalCents: arrivals.isEmpty ? nil : arrivals.reduce(0, +) / Double(arrivals.count),
            meanShiftDurationMs: PositionAnalysis.meanShiftDurationMs(from: samples),
            parasiteGlides: samples.filter {
                $0.isShift && !$0.isVoluntaryGlide && ($0.glideMs ?? 0) >= 150
            }.count,
            voluntaryGlides: samples.filter { $0.isShift && $0.isVoluntaryGlide }.count
        )
    }

    /// Ouvre le replay du dernier moment terminé (mode morceau).
    func replayLastMoment() {
        guard let moment = pieceLastMoment else {
            message = "Aucune note appariée à revoir pour l'instant."
            return
        }
        liveReplay = moment
    }

    private func handlePose(_ frame: PoseFrame?) {
        guard let frame else {
            overlayLandmarks = []
            if phase == .running || phase == .calibrating || pieceRunning {
                cameraStatus = "Caméra active — personne non détectée"
            }
            return
        }

        overlayLandmarks = frame.landmarks
        if phase == .running || phase == .calibrating || pieceRunning {
            cameraStatus = "Suivi OK"
        }

        report.framesAnalyzed += 1
        if !frame.landmarks.isEmpty {
            report.personDetectedFrames += 1
        }

        if phase == .running {
            var lookup: [VNHumanBodyPoseObservation.JointName: Landmark] = [:]
            for landmark in frame.landmarks {
                lookup[landmark.joint] = landmark
            }
            if let wrist = lookup[.rightWrist],
               let shoulder = lookup[.rightShoulder],
               let head = lookup[.nose] ?? lookup[.neck] {
                motionAnalyzer.add(
                    wrist: wrist.point,
                    head: head.point,
                    shoulder: shoulder.point,
                    timestamp: frame.timestamp
                )
            }
        }

        if pieceRunning || phase == .running {
            let body = bodyReference(from: frame)
            if let metrics = leftHandAnalyzer.analyze(
                hands: frame.hands,
                body: body,
                timestamp: frame.timestamp
            ) {
                currentHandMetrics = metrics
                report.addHand(metrics)
                if pieceRunning {
                    if metrics.valid {
                        let presser = metrics.presserFinger.map { $0 == 0 ? "corde à vide" : ($0 == 5 ? "pouce" : "\($0)e doigt") } ?? "—"
                        let confidence = Int((metrics.presserConfidence * 100).rounded())
                        pieceHandStatus = "Main gauche détectée · doigt presseur \(presser) (\(confidence) %)"
                    } else {
                        pieceHandStatus = "Main gauche partielle — angle non mesuré"
                    }
                }
            } else {
                currentHandMetrics = nil
                report.addHandMiss(timestamp: frame.timestamp)
                if pieceRunning {
                    pieceHandStatus = "Main gauche : non détectée"
                }
            }
        }

        switch phase {
        case .calibrating:
            collectCalibration(frame.metrics)
        case .running:
            alerts = rules.evaluate(frame.metrics, now: Date())
            updateLivePosture(frame.metrics)
        default:
            break
        }
    }

    /// Repères corporels gauche issus de Vision Body, pour la main gauche.
    private func bodyReference(from frame: PoseFrame) -> BodyReference {
        var lookup: [VNHumanBodyPoseObservation.JointName: Landmark] = [:]
        for landmark in frame.landmarks {
            lookup[landmark.joint] = landmark
        }
        return BodyReference(
            leftShoulder: lookup[.leftShoulder]?.point,
            leftElbow: lookup[.leftElbow]?.point,
            leftWrist: lookup[.leftWrist]?.point,
            shoulderWidth: frame.metrics.valid ? frame.metrics.shoulderWidth : nil
        )
    }

    /// Jauges de position en direct, rafraîchies à 4 Hz maximum (l'analyse tourne à ~15 fps).
    private func updateLivePosture(_ metrics: PoseMetrics) {
        let now = CACurrentMediaTime()
        guard now - lastLivePostureAt >= 0.25 else { return }
        lastLivePostureAt = now
        livePosture = rules.liveStatus(for: metrics)
    }

    private func collectCalibration(_ metrics: PoseMetrics) {
        guard metrics.valid else { return }
        let now = CACurrentMediaTime()
        guard now - lastCalibrationSampleAt >= 0.25 else { return }
        lastCalibrationSampleAt = now

        calibrationSamples.append(metrics)
        if calibrationSamples.count >= 12 {
            rules.calibrate(calibrationSamples)
            calibrationSamples = []
            phase = .idle
            baselineStatus = "Baseline posture : calibrée ✅"
            camera.stop()
        }
    }

    private func handlePitch(_ frame: PitchFrame) {
        rms = min(1, frame.rms * 4)

        if (pieceRunning || phase == .running), let frequency = frame.frequency, frequency > 0 {
            let midi = 69 + 12 * log2(frequency / 440)
            pitchSamples.append(PitchSample(time: frame.timestamp, midi: midi))
            pitchSamples.removeAll { frame.timestamp - $0.time > 4 }
        }

        if let frequency = frame.frequency {
            let note = NoteNamer.note(for: frequency)
            pitchText = String(format: "%.1f Hz", frequency)
            pitchDetail = String(format: "%@%d · %+.0f cents", note.name, note.octave, note.cents)
            let deviation = abs(note.cents)
            pitchColor = deviation < 10 ? .green : (deviation < 25 ? .orange : .red)

            if phase == .running {
                report.validPitchFrames += 1
                report.addFrequency(frequency)
            }
        } else {
            pitchText = "—"
            pitchDetail = "pas de note détectée"
            pitchColor = .secondary
        }

        if phase == .running {
            report.pitchFrames += 1
            if lastPitchTimestamp > 0 {
                let delta = frame.timestamp - lastPitchTimestamp
                if delta > 0, delta < 2, frame.rms > 0.02 {
                    report.soundingSeconds += delta
                }
            }
            lastPitchTimestamp = frame.timestamp
        }
    }

    private func handleSegment(_ output: SegmenterOutput) {
        switch output {
        case .started(let midi, let time):
            // Glissé/portamento juste avant l'attaque : il appartient au
            // déplacement qui amène la note, pas à la note elle-même.
            let glideWindow = pitchSamples.filter {
                $0.time <= time + 0.02 && $0.time >= time - 1.0
            }
            pendingGlide = GlideDetector.detect(samples: glideWindow)
            pendingGlideVoluntary = false

            if pieceRunning, let follower {
                let feedback = follower.process(midi: midi, onset: time)
                pieceFeedback = feedback
                pieceProgress = feedback.progress
                pieceStats = follower.stats
                pendingFeedback = feedback
                if let index = feedback.scoreIndex, let note = follower.note(at: index) {
                    pendingGlideVoluntary = note.glissando
                }
                let assignment = positionTracker.assign(
                    midi: midi,
                    hand: currentHandMetrics,
                    expected: feedback
                )
                currentAssignment = assignment
                pieceAssignment = assignment
                if assignment.isShift {
                    registerShift(
                        assignment: assignment,
                        glide: pendingGlide,
                        voluntary: pendingGlideVoluntary
                    )
                }
            } else if phase == .running {
                let assignment = positionTracker.assign(
                    midi: midi,
                    hand: currentHandMetrics,
                    expected: nil
                )
                currentAssignment = assignment
                if assignment.isShift {
                    registerShift(assignment: assignment, glide: pendingGlide, voluntary: false)
                }
            }
        case .finished(let event):
            lastNote = event
            let tolerance = settings.intonationTolerance
            let accuracy = NoteAccuracy.evaluate(cents: event.centsToNearest, tolerance: tolerance)

            let gapBefore = previousNoteEnd.map { max(0, event.startTime - $0) } ?? 0
            let pitchChange = previousNoteMidi.map { abs(event.midi - $0) } ?? 0
            recentNoteStarts.removeAll { $0 < event.startTime - 2 }
            recentNoteStarts.append(event.startTime)
            let notesPerSecond = Double(recentNoteStarts.count) / 2

            let features = ArticulationFeatures(
                duration: event.duration,
                attackTime: event.attackTime,
                tailRatio: event.tailRatio,
                rmsVariation: event.rmsVariation,
                gapBefore: gapBefore,
                pitchChange: pitchChange,
                notesPerSecond: notesPerSecond
            )
            let articulation = ArticulationClassifier.classify(features)
            lastArticulation = articulation
            techniqueTracker.addNote(event, articulation: articulation, gapBefore: gapBefore)

            previousNoteEnd = event.endTime
            previousNoteMidi = event.midi

            lastNoteFeedback = NoteFeedback(
                name: NoteNamer.name(forMidi: Int(event.midi.rounded())),
                cents: event.centsToNearest,
                stability: event.stabilityCents,
                hnr: event.hnr,
                accuracy: accuracy,
                isStable: event.stabilityCents <= settings.stabilityTolerance,
                vibratoRate: event.vibratoRate,
                vibratoExtent: event.vibratoExtent,
                articulation: articulation
            )
            if phase == .running {
                report.addNote(event)
                report.addArticulation(articulation.rawValue)
            }

            recordPosition(event: event, articulation: articulation)
            if pieceRunning {
                pieceGlideMs = (event.glideDuration ?? 0) >= 0.08
                    ? (event.glideDuration ?? 0) * 1000
                    : nil
            }
            pendingFeedback = nil
            currentAssignment = nil
            pendingGlide = nil
            pendingGlideVoluntary = false
        }
    }

    /// Enregistre la position/le doigt de la note qui vient de finir.
    /// En mode morceau, seules les notes appariées à la partition entrent dans
    /// les statistiques (les notes hors partition restent comptées ailleurs).
    private func recordPosition(event: NoteEvent, articulation: Articulation) {
        guard let assignment = currentAssignment else { return }

        if pieceRunning {
            guard let feedback = pendingFeedback, feedback.matched, let index = feedback.scoreIndex else {
                return
            }
            let record = NotePositionRecord(
                scoreIndex: index,
                measure: feedback.measure,
                beat: feedback.beat,
                expectedMidi: feedback.expectedMidi,
                playedMidi: Int(event.midi.rounded()),
                cents: feedback.cents ?? event.centsToNearest,
                rhythmMs: feedback.rhythmMs,
                onset: max(0, event.startTime - pieceSessionStart),
                duration: event.duration,
                position: assignment.position,
                finger: assignment.finger,
                fromPosition: assignment.fromPosition,
                fromFinger: assignment.fromFinger,
                direction: assignment.direction.rawValue,
                confidence: assignment.confidence,
                isShift: assignment.isShift,
                glideMs: pendingGlide?.milliseconds,
                glideSlope: pendingGlide?.slope,
                isVoluntaryGlide: pendingGlideVoluntary,
                contour: event.centsContour,
                articulation: articulation.rawValue,
                expectedDuration: feedback.expectedDurationBeats.map {
                    $0 * 60 / max(30, pieceBPM)
                },
                velocity: feedback.expectedVelocity,
                scoreArticulation: feedback.expectedArticulation,
                stringNumber: assignment.stringNumber,
                expectedStringNumber: feedback.expectedStringNumber,
                exactPosition: assignment.exact,
                isThumbPosition: assignment.isThumbPosition
            )
            report.addPosition(record)

            if let follower {
                pieceLastMoment = ReplayBuilder.liveMoment(
                    feedback: feedback,
                    event: event,
                    assignment: assignment,
                    indexedNotes: follower.indexedNotes(around: index, radius: 3),
                    currentIndex: index,
                    bpm: pieceBPM
                )
            }
            return
        }

        guard phase == .running else { return }
        let record = NotePositionRecord(
            scoreIndex: nil,
            measure: nil,
            beat: nil,
            expectedMidi: nil,
            playedMidi: Int(event.midi.rounded()),
            cents: event.centsToNearest,
            rhythmMs: nil,
            onset: event.startTime,
            duration: event.duration,
            position: assignment.position,
            finger: assignment.finger,
            fromPosition: assignment.fromPosition,
            fromFinger: assignment.fromFinger,
            direction: assignment.direction.rawValue,
            confidence: assignment.confidence,
            isShift: assignment.isShift,
            glideMs: pendingGlide?.milliseconds,
            glideSlope: pendingGlide?.slope,
            isVoluntaryGlide: false,
            contour: event.centsContour,
            articulation: articulation.rawValue,
            stringNumber: assignment.stringNumber,
            exactPosition: assignment.exact,
            isThumbPosition: assignment.isThumbPosition
        )
        report.addPosition(record)
    }

    /// Un déplacement avec portamento non écrit est un glissé parasite (B14) ;
    /// si le coude n'accompagne pas, A20 est noté dans le rapport.
    private func registerShift(
        assignment: PositionAssignment,
        glide: GlideInfo?,
        voluntary: Bool
    ) {
        techniqueTracker.addShift(glide: glide, voluntary: voluntary)
        guard !voluntary,
              let glide,
              glide.duration >= 0.15,
              let hand = currentHandMetrics else {
            return
        }
        let thresholds = PostureRules.handThresholds(for: settings.profile)
        report.addHandShift(
            elbowMobility: hand.elbowMobility,
            threshold: thresholds.elbowMobilityMinimum
        )
    }
}
