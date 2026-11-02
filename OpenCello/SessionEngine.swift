import Foundation
import SwiftUI
import AppKit
import QuartzCore
import Vision

enum AppMode: String, CaseIterable {
    case free = "Séance"
    case piece = "Morceau"
    case exercises = "Exercices"
    case progress = "Progrès"
}

enum SessionPhase {
    case idle
    case calibrating
    case running
    case report
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
    @Published var reportMarkdown = ""
    @Published var reportPath: URL?
    @Published var message: String?

    // Mode morceau
    @Published var appMode: AppMode = .free
    @Published var imslpQuery = ""
    @Published var imslpResults: [IMSLPWork] = []
    @Published var imslpLoading = false
    @Published var imslpError: String?
    @Published var imslpComposer: String?
    @Published var imslpUsedFallback = false
    @Published var score: Score?
    @Published var scoreTitle = ""
    @Published var selectedPartIndex = 0
    @Published var pieceBPM: Double = 100
    @Published var pieceRunning = false
    @Published var pieceFeedback: FollowFeedback?
    @Published var pieceProgress: Double = 0
    @Published var pieceStats: PieceStats?
    @Published var lastNote: NoteEvent?
    @Published var lastNoteFeedback: NoteFeedback?
    @Published var recommendedExerciseIDs: [String] = []

    // Mode profil (archet/cordes)
    @Published var analysisMode: AnalysisMode = .posture
    @Published var bowReference: BowReference?
    @Published var bowCalibrationActive = false
    @Published var bowCalibrationPoints: [CGPoint] = []
    @Published var bowLines: [BowLine] = []
    @Published var bowFeedback: BowEvaluation?
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
    private var lastPitchTimestamp: TimeInterval = 0
    private var sessionStartAt: Date?
    private var follower: ScoreFollower?
    private var previousNoteEnd: TimeInterval?
    private var previousNoteMidi: Double?
    private var recentNoteStarts: [TimeInterval] = []
    private let motionAnalyzer = MotionAnalyzer()

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
    }

    private func refreshRecommendationsFromHistory() {
        guard let last = progress.records.first else {
            recommendedExerciseIDs = ExerciseCatalog.recommendations(for: []).map(\.id)
            return
        }
        let ruleIDs = last.posture
            .sorted { $0.seconds > $1.seconds }
            .prefix(3)
            .map(\.ruleID)
        recommendedExerciseIDs = ExerciseCatalog.recommendations(for: Array(ruleIDs)).map(\.id)
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
        phase = .running
        camera.analysisMode = analysisMode
        camera.start()
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
        let markdown = report.markdown(lines: summary, baseline: rules.baselineDescription)
        reportMarkdown = markdown
        reportPath = save(markdown)

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
            reportMarkdown: markdown,
            bow: report.bowFrames > 0
                ? BowRecord(
                    frames: report.bowFrames,
                    goodAngle: report.bowGoodAngle,
                    goodZone: report.bowGoodZone
                )
                : nil
        )
        progress.add(record)

        let ruleIDs = summary
            .sorted { $0.totalBadSeconds > $1.totalBadSeconds }
            .filter { $0.totalBadSeconds > 2 }
            .prefix(3)
            .map(\.id)
        recommendedExerciseIDs = ExerciseCatalog.recommendations(for: Array(ruleIDs)).map(\.id)

        phase = .report
        alerts = []
        bowAlert = nil
    }

    func newSession() {
        phase = .idle
        reportMarkdown = ""
        reportPath = nil
        alerts = []
        overlayLandmarks = []
        pitchText = "—"
        pitchDetail = ""
        pitchColor = .secondary
        rms = 0
        lastNoteFeedback = nil
        bowFeedback = nil
        bowAlert = nil
    }

    func openReport() {
        guard let reportPath else { return }
        NSWorkspace.shared.open(reportPath)
    }

    // MARK: - Mode profil (archet/cordes)

    func setAnalysisMode(_ mode: AnalysisMode) {
        guard phase == .idle, !pieceRunning else { return }
        analysisMode = mode
        camera.analysisMode = mode
        bowFeedback = nil
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
        bowAlert = nil
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
            bowAlert = "Archet non détecté — cadrez de profil"
            return
        }

        bowFeedback = evaluation
        if phase == .running {
            report.bowFrames += 1
            if evaluation.angleOK { report.bowGoodAngle += 1 }
            if evaluation.zoneOK { report.bowGoodZone += 1 }
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
        message = "Titre retenu : \(work.title). Importez le MusicXML correspondant pour lancer le suivi."
    }

    func importScore(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try MusicXMLParser.parse(data: data)
            score = parsed
            scoreTitle = parsed.title
            selectedPartIndex = parsed.defaultPartIndex
            if let tempo = parsed.tempo { pieceBPM = tempo }
            pieceFeedback = nil
            pieceStats = nil
            pieceProgress = 0
            reportMarkdown = ""
            reportPath = nil
            message = "Partition chargée : \(parsed.title)"
        } catch {
            message = "Impossible de lire la partition : \(error.localizedDescription)"
        }
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
        reportMarkdown = ""
        reportPath = nil
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

        camera.stop()
        let newFollower = ScoreFollower(score: score, partIndex: selectedPartIndex, bpm: pieceBPM)
        follower = newFollower
        pieceFeedback = nil
        pieceStats = newFollower.stats
        pieceProgress = 0
        reportMarkdown = ""
        reportPath = nil
        pieceRunning = true
        mic.start()
    }

    func stopPieceSession() {
        guard pieceRunning else { return }
        pieceRunning = false
        mic.stop()

        if let follower {
            pieceStats = follower.stats
            let markdown = report.pieceMarkdown(
                title: scoreTitle.isEmpty ? "Morceau" : scoreTitle,
                stats: follower.stats,
                bpm: pieceBPM
            )
            reportMarkdown = markdown
            reportPath = save(markdown)

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
                reportMarkdown: markdown
            )
            progress.add(record)
            recommendedExerciseIDs = ExerciseCatalog.recommendations(for: ["B1"]).map(\.id)
        }

        pieceFeedback = nil
        follower = nil
    }

    private func handlePose(_ frame: PoseFrame?) {
        guard let frame else {
            overlayLandmarks = []
            if phase == .running || phase == .calibrating {
                cameraStatus = "Caméra active — personne non détectée"
            }
            return
        }

        overlayLandmarks = frame.landmarks
        if phase == .running || phase == .calibrating {
            cameraStatus = "Suivi OK"
        }

        report.framesAnalyzed += 1
        report.personDetectedFrames += 1

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

        switch phase {
        case .calibrating:
            collectCalibration(frame.metrics)
        case .running:
            alerts = rules.evaluate(frame.metrics, now: Date())
        default:
            break
        }
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
            guard pieceRunning, let follower else { return }
            let feedback = follower.process(midi: midi, onset: time)
            pieceFeedback = feedback
            pieceProgress = feedback.progress
            pieceStats = follower.stats
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
        }
    }

    private func save(_ markdown: String) -> URL? {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = documents.appendingPathComponent("OpenCello/Rapports", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let url = directory.appendingPathComponent("session_\(formatter.string(from: Date())).md")
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            message = "Impossible d'écrire le rapport : \(error.localizedDescription)"
            return nil
        }
    }
}
