import Foundation

@main
struct Phase7Test {
    static var failures = 0

    static func check(_ condition: Bool, _ message: String = "condition") {
        if !condition {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        testHandAnalyzer()
        testPositionTracker()
        testPositionAnalysis()
        testGlideDetector()
        testTechniqueTracker()
        testReplay()
        testSessionReport()
        testReportCommentary()
        testExercises()
        testPersistence()
        testMusicXML()
        testFollower()
        if failures == 0 {
            print("PHASE7: OK")
        } else {
            print("PHASE7: \(failures) échec(s)")
            exit(1)
        }
    }

    // MARK: - Main gauche

    static func makeHandFrame() -> HandFrame {
        let points: [(HandJoint, CGPoint)] = [
            (.wrist, CGPoint(x: 0.50, y: 0.50)),
            (.thumbCMC, CGPoint(x: 0.44, y: 0.46)),
            (.thumbMP, CGPoint(x: 0.43, y: 0.44)),
            (.thumbIP, CGPoint(x: 0.42, y: 0.43)),
            (.thumbTip, CGPoint(x: 0.41, y: 0.42)),
            (.indexMCP, CGPoint(x: 0.52, y: 0.48)),
            (.indexPIP, CGPoint(x: 0.54, y: 0.45)),
            (.indexTip, CGPoint(x: 0.55, y: 0.42)),
            (.middleMCP, CGPoint(x: 0.54, y: 0.49)),
            (.middlePIP, CGPoint(x: 0.56, y: 0.45)),
            (.middleTip, CGPoint(x: 0.57, y: 0.40)),
            (.ringMCP, CGPoint(x: 0.56, y: 0.50)),
            (.ringPIP, CGPoint(x: 0.58, y: 0.47)),
            (.ringTip, CGPoint(x: 0.59, y: 0.43)),
            (.littleMCP, CGPoint(x: 0.58, y: 0.51)),
            (.littlePIP, CGPoint(x: 0.60, y: 0.48)),
            (.littleTip, CGPoint(x: 0.61, y: 0.45))
        ]
        return HandFrame(
            points: points.map { HandPoint(joint: $0.0, point: $0.1, confidence: 0.9) },
            confidence: 0.9,
            timestamp: 1.0
        )
    }

    static func testHandAnalyzer() {
        let analyzer = LeftHandAnalyzer()
        let body = BodyReference(
            leftShoulder: CGPoint(x: 0.40, y: 0.70),
            leftElbow: CGPoint(x: 0.40, y: 0.50),
            leftWrist: CGPoint(x: 0.50, y: 0.50),
            shoulderWidth: 0.20
        )
        guard let metrics = analyzer.analyze(
            hands: [makeHandFrame()],
            body: body,
            timestamp: 1.0
        ) else {
            print("HAND: FAIL (aucune métrique)")
            return
        }
        let angle = metrics.handAngleDegrees ?? -1
        let presser = metrics.presserFinger ?? -1
        let curl = metrics.fingerCurl ?? -1
        print(String(format: "HAND: angle %.1f° · presseur %d · curl %.2f · position %@",
                     angle, presser, curl, metrics.positionHint.map(String.init) ?? "—"))
        check(metrics.valid)
        check(angle >= 0 && angle <= 90, "angle main plausible")
        check(presser == 2, "doigt presseur 2")
        check(curl >= 0 && curl <= 1)
        check(metrics.positionHint != nil, "position hint présent")

        var thumbPoints = makeHandFrame().points
        thumbPoints = thumbPoints.map { point in
            guard point.joint == .thumbTip else { return point }
            return HandPoint(joint: .thumbTip, point: CGPoint(x: 0.57, y: 0.30), confidence: 0.9)
        }
        let thumbFrame = HandFrame(points: thumbPoints, confidence: 0.9, timestamp: 1.0)
        let thumbMetrics = LeftHandAnalyzer().analyze(hands: [thumbFrame], body: body, timestamp: 1.0)
        print("HAND pouce: presseur \(thumbMetrics?.presserFinger ?? -1)")
        check(thumbMetrics?.presserFinger == 5, "pouce détecté comme doigt presseur")
    }

    // MARK: - Positions

    static func testPositionTracker() {
        let tracker = PositionTracker()
        let hand = LeftHandMetrics(
            valid: true,
            presserFinger: 4,
            presserConfidence: 0.6,
            positionHint: 4,
            positionHintConfidence: 0.4
        )
        let assignment = tracker.assign(midi: 60, hand: hand, expected: nil)
        print("POSITION 60: \(assignment.position.map(String.init) ?? "—")e · doigt \(assignment.finger.map(String.init) ?? "—") · conf \(String(format: "%.2f", assignment.confidence)) · \(assignment.source)")
        check(assignment.position == 4, "position 4")
        check(assignment.finger == 4, "doigt 4")
        check(assignment.confidence > 0.5, "confiance > 0,5")
        check(assignment.stringMidi == 50, "corde ré")
        check(assignment.exact, "position exacte via note + doigt + caméra")

        let open = tracker.assign(midi: 43, hand: LeftHandMetrics(valid: true), expected: nil)
        let openPosition = open.position.map { "\($0)e" } ?? "—"
        print("POSITION 43: \(openPosition) · doigt \(open.finger.map(String.init) ?? "—") · corde à vide \(open.isOpenString)")
        check(open.isOpenString, "corde à vide reconnue")
        check(open.finger == 0, "doigt 0")
        check(open.position == nil, "pas de position inventée pour une corde à vide")
        check(open.stringNumber == 3, "corde à vide sol")

        // Position exacte : note + doigt + corde écrite dans le MusicXML.
        let exactTracker = PositionTracker()
        let exactHand = LeftHandMetrics(
            valid: true,
            presserFinger: 1,
            presserConfidence: 0.7,
            positionHint: 4,
            positionHintConfidence: 0.3
        )
        var exactExpected = FollowFeedback()
        exactExpected.expectedMidi = 62
        exactExpected.expectedStringNumber = 1
        exactExpected.expectedFingering = 1
        let exact = exactTracker.assign(midi: 62, hand: exactHand, expected: exactExpected)
        print("POSITION exacte: \(exact.positionText) · \(exact.fingerText) · \(exact.stringText) · exacte \(exact.exact) · \(exact.source)")
        check(exact.exact, "position exacte note + doigt + corde")
        check(exact.position == 4, "62 sur la corde de la = 4e position, 1er doigt")
        check(exact.stringNumber == 1, "corde la")

        // Pouce en position haute.
        let thumbTracker = PositionTracker()
        let thumbHand = LeftHandMetrics(
            valid: true,
            presserFinger: 5,
            presserConfidence: 0.7,
            positionHint: 8,
            positionHintConfidence: 0.3
        )
        var thumbExpected = FollowFeedback()
        thumbExpected.expectedMidi = 64
        thumbExpected.expectedStringNumber = 1
        thumbExpected.expectedFingering = 5
        let thumb = thumbTracker.assign(midi: 64, hand: thumbHand, expected: thumbExpected)
        print("POUSSÉ: \(thumb.positionText) · \(thumb.fingerText) · exacte \(thumb.exact)")
        check(thumb.exact, "position du pouce exacte")
        check(thumb.isThumbPosition, "pouce reconnu")
        check(thumb.position == 8, "64 sur la corde de la = pouce 8e")

        // Continuité : la note suivante reste dans la même région.
        let next = tracker.assign(midi: 61, hand: hand, expected: nil)
        print("POSITION 61: \(next.position.map(String.init) ?? "—")e · doigt \(next.finger.map(String.init) ?? "—") · \(next.direction.rawValue)")
        check(next.position != nil, "position suivante")
    }

    static func makePositionNote(
        index: Int,
        cents: Double,
        position: Int,
        finger: Int,
        from: Int? = nil,
        direction: String = "sur place",
        isShift: Bool = false,
        glideMs: Double? = nil,
        voluntary: Bool = false,
        rhythmMs: Double? = nil
    ) -> NotePositionRecord {
        NotePositionRecord(
            scoreIndex: index,
            measure: index / 2 + 1,
            beat: Double(index % 2 + 1),
            expectedMidi: 60 + index,
            playedMidi: 60 + index,
            cents: cents,
            rhythmMs: rhythmMs,
            onset: Double(index) * 0.5,
            duration: 0.4,
            position: position,
            finger: finger,
            fromPosition: from,
            fromFinger: nil,
            direction: direction,
            confidence: 0.8,
            isShift: isShift,
            glideMs: glideMs,
            glideSlope: glideMs.map { _ in 400 },
            isVoluntaryGlide: voluntary,
            contour: [cents, cents + 5, cents - 3, cents],
            articulation: "détaché"
        )
    }

    static func testPositionAnalysis() {
        let notes = [
            makePositionNote(index: 0, cents: -10, position: 1, finger: 1),
            makePositionNote(index: 1, cents: -40, position: 4, finger: 2, from: 1, direction: "montée", isShift: true, glideMs: 220),
            makePositionNote(index: 2, cents: -35, position: 4, finger: 2, from: 1, direction: "montée", isShift: true, glideMs: 180),
            makePositionNote(index: 3, cents: 20, position: 4, finger: 2)
        ]
        let aggregates = PositionAnalysis.aggregates(from: notes)
        let worst = PositionAnalysis.worstShift(from: notes)
        let parasite = PositionAnalysis.parasiteGlideSummary(from: notes)
        print("POSITIONS: \(aggregates.count) agrégats · pire shift \(worst?.label ?? "—") · glissés \(parasite?.parasite ?? 0)/\(parasite?.total ?? 0)")
        check(aggregates.count >= 2, "agrégats")
        check(worst != nil, "pire déplacement")
        check(parasite != nil, "glissés parasites")
        check(PositionAnalysis.meanShiftDurationMs(from: notes) == 200, "durée moyenne 200 ms")
    }

    // MARK: - Glissé

    static func testGlideDetector() {
        let samples = (0..<20).map { index -> PitchSample in
            let time = Double(index) * 0.02
            return PitchSample(time: time, midi: 60 + time * 1.0)
        }
        guard let glide = GlideDetector.detect(samples: samples) else {
            print("GLIDE: FAIL (aucun glissé)")
            return
        }
        print(String(format: "GLIDE: %.0f ms · %.0f cents · %.0f cents/s", glide.milliseconds, glide.cents, glide.slope))
        check(glide.isGlide, "glissé détecté")
        check(glide.duration > 0.2, "durée > 200 ms")
        check(abs(glide.cents) > 20, "amplitude > 20 cents")
    }

    // MARK: - Piqué

    static func makeEvent(start: Double, duration: Double, rms: Double) -> NoteEvent {
        NoteEvent(
            startTime: start,
            endTime: start + duration,
            midi: 60,
            frequency: 261.63,
            centsToNearest: 0,
            stabilityCents: 3,
            meanRMS: rms,
            rmsVariation: 0.1,
            attackTime: 0.02,
            tailRatio: 0.1,
            centroid: 1000,
            flatness: 0.2,
            highBandRatio: 0.3,
            hnr: 20,
            confidence: 0.9,
            vibratoRate: nil,
            vibratoExtent: nil
        )
    }

    static func testTechniqueTracker() {
        let regular = TechniqueTracker()
        for index in 0..<6 {
            regular.addNote(makeEvent(start: Double(index) * 0.2, duration: 0.15, rms: 0.3), articulation: .staccato, gapBefore: 0.05)
        }
        let regularRecord = regular.record()
        print(String(format: "PIQUE régulier: %d notes · %d série inégale · régularité %.2f",
                     regularRecord?.piqueNotes ?? 0,
                     regularRecord?.piqueUnevenRuns ?? 0,
                     regularRecord?.piqueRegularity ?? 0))
        check(regularRecord?.piqueNotes == 6, "6 notes piquées")
        check(regularRecord?.piqueUnevenRuns == 0, "aucune série inégale")
        check((regularRecord?.piqueRegularity ?? 0) > 0.8, "régularité élevée")

        let uneven = TechniqueTracker()
        let durations: [Double] = [0.10, 0.20, 0.10, 0.20, 0.10, 0.20]
        for (index, duration) in durations.enumerated() {
            uneven.addNote(makeEvent(start: Double(index) * 0.25, duration: duration, rms: 0.3), articulation: .staccato, gapBefore: 0.05)
        }
        let unevenRecord = uneven.record()
        print("PIQUE inégal: \(unevenRecord?.piqueUnevenRuns ?? 0) série(s) · déviation \(unevenRecord?.piqueWorstDeviation ?? 0)")
        check((unevenRecord?.piqueUnevenRuns ?? 0) == 1, "une série inégale")

        let glide = GlideInfo(duration: 0.22, cents: 100, slope: 454)
        uneven.addShift(glide: glide, voluntary: false)
        uneven.addShift(glide: glide, voluntary: true)
        let technique = uneven.record()
        print("GLISSES: \(technique?.parasiteGlides ?? 0) parasites · \(technique?.voluntaryGlides ?? 0) volontaires")
        check(technique?.parasiteGlides == 1, "un glissé parasite")
        check(technique?.voluntaryGlides == 1, "un glissé volontaire")
    }

    // MARK: - Replay

    static func testReplay() {
        let notes = [
            makePositionNote(index: 0, cents: -40, position: 1, finger: 1, rhythmMs: 200),
            makePositionNote(index: 1, cents: 30, position: 3, finger: 2, from: 1, direction: "montée", isShift: true, glideMs: 220),
            makePositionNote(index: 2, cents: 40, position: 3, finger: 2),
            makePositionNote(index: 3, cents: 0, position: 3, finger: 3)
        ]
        let technique = TechniqueRecord(
            piqueNotes: 6,
            piqueUnevenRuns: 1,
            piqueMeanDurationCV: 0.2,
            piqueMeanEnergyCV: 0.1,
            piqueWorstIndex: 2,
            piqueWorstDeviation: -0.18,
            glideShifts: 1,
            parasiteGlides: 1,
            voluntaryGlides: 0,
            meanGlideMs: 220,
            meanGlideSlope: 400
        )
        let moments = ReplayBuilder.moments(from: notes, technique: technique)
        print("REPLAY: \(moments.map(\.kind).joined(separator: ", "))")
        check(moments.count >= 4, "moments de replay")
        check(moments.contains { $0.kind == "Justesse" }, "moment justesse")
        check(moments.contains { $0.kind == "Rythme" }, "moment rythme")
        check(moments.contains { $0.kind == "Glissé" }, "moment glissé")
        check(moments.contains { $0.kind == "Déplacement" }, "moment déplacement")

        guard let moment = moments.first else { return }
        let played = ReplaySynth.render(moment: moment, corrected: false)
        let corrected = ReplaySynth.render(moment: moment, corrected: true)
        print("SYNTH: \(played.count) échantillons · joué != corrigé \(played != corrected)")
        check(!played.isEmpty, "échantillons synthétisés")
        check(played.count == corrected.count, "même durée")
        check(played != corrected, "versions différentes")
        check((played.map { abs($0) }.max() ?? 0) <= 0.8, "pas de saturation")

        if let xml = ReplayStaffXML.musicXML(for: moment),
           let staffScore = try? MusicXMLParser.parse(data: xml) {
            let staffNotes = staffPartNotes(staffScore)
            print("STAFF XML: \(xml.count) octets · \(staffNotes) notes")
            check(staffNotes == moment.notes.count, "portée : toutes les notes du moment")
            if ProcessInfo.processInfo.environment["WRITE_STAFF"] == "1" {
                try? xml.write(to: URL(fileURLWithPath: "/tmp/opencello_staff.xml"))
            }
        } else {
            check(false, "portée : MusicXML généré invalide")
        }
    }

    static func staffPartNotes(_ score: Score) -> Int {
        score.parts.map { $0.notes.count }.max() ?? 0
    }

    // MARK: - Rapport de séance

    static func testSessionReport() {
        let report = SessionReport()
        report.reset(startedAt: Date())
        let first = LeftHandMetrics(
            valid: true,
            handAngleDegrees: 22,
            signedHandAngleDegrees: 22,
            fingerCurl: 0.4,
            fingerSpeed: 1.2,
            fingerSpeedP90: 3.1,
            presserFinger: 2,
            presserConfidence: 0.7,
            thumbHypothesis: true,
            thumbConfidence: 0.4,
            positionHint: 3,
            positionHintConfidence: 0.3,
            elbowMobility: 0.02,
            flags: ["A17": true, "A18": true, "A19": true],
            timestamp: 1.0
        )
        report.addHand(first)
        var second = first
        second.timestamp = 1.2
        second.handAngleDegrees = 18
        report.addHand(second)
        report.addHandShift(elbowMobility: 0.01, threshold: 0.05)
        report.addPosition(makePositionNote(index: 0, cents: -10, position: 1, finger: 1))

        let hand = report.handRecord()
        print("SESSIONREPORT: frames \(hand?.frames ?? 0) · valides \(hand?.validFrames ?? 0) · A20 \(hand?.rules.first { $0.ruleID == "A20" }?.occurrences ?? 0)")
        check(hand?.frames == 2, "2 frames main")
        check(hand?.validFrames == 2, "2 frames valides")
        check(hand?.rules.count == 4, "4 règles main")
        check(hand?.rules.first { $0.ruleID == "A20" }?.occurrences == 1, "A20 compté")
        check(hand?.thumbHypothesisRatio == 1, "pouce hypothèse")
        check(report.positionSamples.count == 1, "note de position")
    }

    // MARK: - Commentaires

    static func testReportCommentary() {
        let hand = HandRecord(
            frames: 100,
            validFrames: 80,
            meanAngleDegrees: 19,
            meanSignedAngleDegrees: 19,
            maxAngleDegrees: 28,
            meanFingerSpeed: 1.8,
            meanPresserConfidence: 0.6,
            thumbHypothesisRatio: 0.4,
            rules: [
                HandRuleRecord(ruleID: "A17", title: "Main gauche cassée", seconds: 22, occurrences: 3, confidence: nil),
                HandRuleRecord(ruleID: "A18", title: "Pouce gauche crispé (hypothèse)", seconds: 30, occurrences: 2, confidence: "hypothèse"),
                HandRuleRecord(ruleID: "A19", title: "Doigts raides ou frappe brutale", seconds: 4, occurrences: 1, confidence: nil),
                HandRuleRecord(ruleID: "A20", title: "Coude gauche qui ne guide pas", seconds: 0.5, occurrences: 1, confidence: nil)
            ]
        )
        let samples = [
            makePositionNote(index: 0, cents: -10, position: 1, finger: 1),
            makePositionNote(index: 1, cents: -40, position: 4, finger: 2, from: 1, direction: "montée", isShift: true, glideMs: 220),
            makePositionNote(index: 2, cents: -35, position: 4, finger: 2, from: 1, direction: "montée", isShift: true, glideMs: 180)
        ]
        let stats = PositionStatsRecord(
            samples: samples,
            shiftCount: 2,
            meanArrivalCents: -37.5,
            meanShiftDurationMs: 200,
            parasiteGlides: 2,
            voluntaryGlides: 0
        )
        let technique = TechniqueRecord(
            piqueNotes: 6,
            piqueUnevenRuns: 1,
            piqueMeanDurationCV: 0.2,
            piqueMeanEnergyCV: 0.1,
            piqueWorstIndex: 2,
            piqueWorstDeviation: -0.18,
            glideShifts: 2,
            parasiteGlides: 2,
            voluntaryGlides: 0,
            meanGlideMs: 200,
            meanGlideSlope: 400
        )
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            mode: "Morceau",
            title: "Test",
            duration: 300,
            posture: [],
            noteCount: 20,
            inTuneNotes: 12,
            meanAbsCents: 28,
            meanStability: 9,
            soundingSeconds: 0,
            noteCents: [],
            noteStability: [],
            piece: nil,
            hand: hand,
            positionStats: stats,
            technique: technique
        )
        let commentary = ReportCommentary.build(for: record, previous: nil, settings: AppSettings())
        print("COMMENTARY: main \(commentary.leftHand.count) · positions \(commentary.positions.count) · techniques \(commentary.techniques.count) · exercices \(commentary.exercises.map(\.id).joined(separator: ","))")
        check(!commentary.leftHand.isEmpty, "commentaires main gauche")
        check(!commentary.positions.isEmpty, "commentaires positions")
        check(!commentary.techniques.isEmpty, "commentaires techniques")
        check(commentary.confidence.contains("main gauche"), "confiance main gauche")
        check(commentary.confidence.contains("position estimée"), "confiance position")
        check(commentary.global.contains("prioritaire"), "priorité globale")
        check(!commentary.exercises.isEmpty, "exercices recommandés")
    }

    // MARK: - Exercices

    static func testExercises() {
        let all = ExerciseCatalog.all
        let ids = Set(all.map(\.id))
        print("EXERCISES: \(all.count) · E3-07 \(ids.contains("E3-07")) · E4-07 \(ids.contains("E4-07")) · E4-08 \(ids.contains("E4-08")) · E4-09 \(ids.contains("E4-09"))")
        check(all.count == 29, "29 exercices")
        check(ids.contains("E3-07"), "E3-07")
        check(ids.contains("E4-07"), "E4-07")
        check(ids.contains("E4-08"), "E4-08")
        check(ids.contains("E4-09"), "E4-09")
        let recommended = ExerciseCatalog.recommendations(for: ["A17", "B14", "B17"], limit: 6).map(\.id)
        print("RECOMMENDATIONS: \(recommended.joined(separator: ","))")
        check(recommended.contains("E4-09"), "recommandation E4-09")
        check(recommended.contains("E4-08"), "recommandation E4-08")
        check(recommended.contains("E3-07"), "recommandation E3-07")
    }

    // MARK: - Persistance

    static func testPersistence() {
        let hand = HandRecord(
            frames: 10,
            validFrames: 8,
            meanAngleDegrees: 12,
            meanSignedAngleDegrees: 12,
            maxAngleDegrees: 20,
            meanFingerSpeed: 1.5,
            meanPresserConfidence: 0.5,
            thumbHypothesisRatio: 0.2,
            rules: [HandRuleRecord(ruleID: "A17", title: "Main gauche cassée", seconds: 2, occurrences: 1, confidence: nil)]
        )
        let note = makePositionNote(index: 0, cents: -20, position: 2, finger: 1, from: 1, direction: "montée", isShift: true, glideMs: 180)
        let stats = PositionStatsRecord(samples: [note], shiftCount: 1, meanArrivalCents: -20, meanShiftDurationMs: 180, parasiteGlides: 1, voluntaryGlides: 0)
        let technique = TechniqueRecord(
            piqueNotes: 4, piqueUnevenRuns: 0, piqueMeanDurationCV: 0.05, piqueMeanEnergyCV: 0.04,
            piqueWorstIndex: nil, piqueWorstDeviation: nil, glideShifts: 1, parasiteGlides: 1,
            voluntaryGlides: 0, meanGlideMs: 180, meanGlideSlope: 350
        )
        let moment = ReplayMoment(
            kind: "Glissé",
            title: "Glissé — mesure 1",
            detail: "portamento de 180 ms",
            advice: "Pose le doigt d'un coup.",
            measure: 1,
            beat: 1,
            scoreIndex: 0,
            expectedMidi: 60,
            cents: -20,
            rhythmMs: 0,
            glideMs: 180,
            position: 2,
            finger: 1,
            notes: [ReplayNote(scoreIndex: 0, measure: 1, beat: 1, midi: 60, onset: 0, duration: 0.4, cents: -20, contour: [-20, -15], rhythmMs: 0)]
        )
        let record = SessionRecord(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            mode: "Morceau",
            title: "Test",
            duration: 120,
            posture: [],
            noteCount: 4,
            inTuneNotes: 3,
            meanAbsCents: 12,
            meanStability: 5,
            soundingSeconds: 0,
            noteCents: [],
            noteStability: [],
            piece: nil,
            hand: hand,
            positionStats: stats,
            technique: technique,
            replayMoments: [moment]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? encoder.encode(record),
              let decoded = try? decoder.decode(SessionRecord.self, from: data) else {
            print("PERSISTENCE: FAIL")
            return
        }
        print("PERSISTENCE: hand \(decoded.hand?.frames ?? 0) · notes \(decoded.positionStats?.samples.count ?? 0) · replay \(decoded.replayMoments?.count ?? 0)")
        check(decoded.hand?.frames == 10, "hand décodé")
        check(decoded.positionStats?.samples.count == 1, "positions décodées")
        check(decoded.replayMoments?.count == 1, "replay décodé")
        check(decoded.technique?.piqueNotes == 4, "technique décodée")
        check(decoded.pieceNotes.count == 1, "pieceNotes")

        // Rétro-compatibilité : JSON v1.0 sans aucun champ v1.1.
        let legacy: [String: Any] = [
            "id": UUID().uuidString,
            "date": "2026-11-03T10:00:00Z",
            "mode": "Séance libre",
            "title": "Ancienne séance",
            "duration": 60.0,
            "posture": [],
            "noteCount": 1,
            "inTuneNotes": 1,
            "meanAbsCents": 5.0,
            "meanStability": 3.0,
            "soundingSeconds": 20.0,
            "noteCents": [5.0],
            "noteStability": [3.0]
        ]
        guard let legacyData = try? JSONSerialization.data(withJSONObject: legacy),
              let legacyRecord = try? decoder.decode(SessionRecord.self, from: legacyData) else {
            print("LEGACY: FAIL")
            return
        }
        print("LEGACY: hand \(legacyRecord.hand == nil) · positions \(legacyRecord.positionStats == nil)")
        check(legacyRecord.hand == nil, "legacy hand nil")
        check(legacyRecord.positionStats == nil, "legacy positions nil")
        check(legacyRecord.replayMoments == nil, "legacy replay nil")
    }

    // MARK: - MusicXML

    static func testMusicXML() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <work><work-title>Test phase 7</work-title></work>
          <part-list>
            <score-part id="P1"><part-name>Cello</part-name></score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>2</divisions></attributes>
              <direction>
                <direction-type><dynamics><mf/></dynamics></direction-type>
              </direction>
              <note>
                <pitch><step>C</step><octave>3</octave></pitch>
                <duration>2</duration>
                <notations><glissando type="start">gliss.</glissando><technical><string>3</string></technical></notations>
              </note>
              <note>
                <pitch><step>D</step><octave>3</octave></pitch>
                <duration>2</duration>
                <notations><fingering>2</fingering><staccato/></notations>
              </note>
            </measure>
            <measure number="2">
              <note>
                <pitch><step>E</step><octave>3</octave></pitch>
                <duration>4</duration>
                <notations><pizzicato/></notations>
              </note>
            </measure>
          </part>
        </score-partwise>
        """
        guard let score = try? MusicXMLParser.parse(data: Data(xml.utf8)) else {
            print("MUSICXML: FAIL")
            return
        }
        let notes = score.parts[0].notes
        print("MUSICXML: \(notes.count) notes · glissando \(notes[0].glissando) · fingering \(notes[1].fingering ?? -1) · vélocité \(notes[0].velocity ?? -1) · corde \(notes[0].stringNumber ?? -1) · articulation \(notes[1].scoreArticulation ?? "—") · pizz \(notes[2].scoreArticulation ?? "—") · mesure2 début \(notes[2].measureStartBeats)")
        check(notes.count == 3, "3 notes MusicXML")
        check(notes[0].glissando, "glissando")
        check(notes[1].fingering == 2, "fingering")
        check(notes[0].velocity == 90, "nuance mf → vélocité 90")
        check(notes[0].stringNumber == 3, "corde 3 (sol)")
        check(notes[1].scoreArticulation == "staccato", "articulation staccato")
        check(notes[2].scoreArticulation == "pizzicato", "articulation pizzicato")
        check(notes[2].measureStartBeats == 2, "mesure 2")
        check(notes[2].onsetBeats == 2, "onset mesure 2")
    }

    // MARK: - Suivi de partition

    static func testFollower() {
        let notes = (0..<5).map { index in
            ScoreNote(
                midi: 60 + index,
                onsetBeats: Double(index),
                durationBeats: 1,
                measureIndex: 1,
                measureStartBeats: 0
            )
        }
        let score = Score(title: "Test", composer: nil, tempo: 100, parts: [ScorePart(name: "Cello", notes: notes)])
        let follower = ScoreFollower(score: score, partIndex: 0, bpm: 100)
        let indexed = follower.indexedNotes(around: 2, radius: 1)
        print("FOLLOWER: \(indexed.map(\.index)) · note 2 = \(follower.note(at: 2)?.midi ?? -1)")
        check(indexed.map(\.index) == [1, 2, 3], "fenêtre indexée")
        check(follower.note(at: 2)?.midi == 62, "note 2")
        check(follower.notes(around: 0, radius: 1).count == 2, "notes autour de 0")

        // Accord (double corde) : le MusicXML est groupé, mais l'audio reste
        // monophonique ; le feedback doit le dire explicitement.
        let chordNotes = [
            ScoreNote(midi: 60, onsetBeats: 0, durationBeats: 1, measureIndex: 1, measureStartBeats: 0),
            ScoreNote(midi: 64, onsetBeats: 0, durationBeats: 1, measureIndex: 1, measureStartBeats: 0)
        ]
        let chordScore = Score(title: "Accord", composer: nil, tempo: 100, parts: [ScorePart(name: "Cello", notes: chordNotes)])
        let chordFollower = ScoreFollower(score: chordScore, partIndex: 0, bpm: 100)
        let chordFeedback = chordFollower.process(midi: 60, onset: 0)
        print("CHORD: size \(chordFeedback.chordSize ?? -1) · \(chordFeedback.message)")
        check(chordFeedback.matched, "accord : une note appariée")
        check(chordFeedback.chordSize == 2, "accord : 2 notes détectées dans le MusicXML")
        check(chordFeedback.message.contains("Accord"), "accord : feedback explicite")
    }
}
