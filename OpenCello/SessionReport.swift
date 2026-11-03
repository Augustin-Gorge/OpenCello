import Foundation

/// Statistiques agrégées d'une séance (posture + son).
/// La mise en forme des rapports vit dans l'app (ReportView / ProfileView) :
/// aucune génération de fichier Markdown.
final class SessionReport {
    var startedAt: Date?
    var endedAt: Date?
    var framesAnalyzed = 0
    var personDetectedFrames = 0
    var pitchFrames = 0
    var validPitchFrames = 0
    var soundingSeconds: Double = 0
    var frequencies: [Double] = []

    var noteCount = 0
    var inTuneNotes = 0
    var sumAbsCents = 0.0
    var sumStability = 0.0
    var sumHNR = 0.0
    var sumCentroid = 0.0
    var sumRMSVariation = 0.0
    var noteCents: [Double] = []
    var noteStability: [Double] = []
    var bowFrames = 0
    var bowGoodAngle = 0
    var bowGoodZone = 0
    var bowContactSum = 0.0
    var bowAngleSum = 0.0
    var bowSpeedSum = 0.0
    var bowTastoFrames = 0
    var bowMiddleFrames = 0
    var bowBridgeFrames = 0
    var bowDirectionChanges = 0
    var vibratoSamples = 0
    var sumVibratoRate = 0.0
    var sumVibratoExtent = 0.0
    var articulationCounts: [String: Int] = [:]
    var motionJerk: Double?
    var motionStillness: Double?
    var motionSamples = 0

    // Main gauche (Phase 7) : accumulation par frame + événements A20.
    var handFrames = 0
    var handDetectedFrames = 0
    var handValidFrames = 0
    var handAngleSum = 0.0
    var handSignedAngleSum = 0.0
    var handAngleMax = 0.0
    var handFingerSpeedSum = 0.0
    var handPresserConfidenceSum = 0.0
    var handThumbFrames = 0
    var handRuleSeconds: [String: Double] = [:]
    var handRuleOccurrences: [String: Int] = [:]
    private var handRuleActive: [String: Bool] = [:]
    private var handLastSampleAt: TimeInterval?
    var positionSamples: [NotePositionRecord] = []

    var duration: TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, (endedAt ?? Date()).timeIntervalSince(startedAt))
    }

    var meanAbsCents: Double {
        noteCount > 0 ? sumAbsCents / Double(noteCount) : 0
    }

    var meanStability: Double {
        noteCount > 0 ? sumStability / Double(noteCount) : 0
    }

    var meanHNR: Double? {
        noteCount > 0 ? sumHNR / Double(noteCount) : nil
    }

    var meanCentroid: Double? {
        noteCount > 0 ? sumCentroid / Double(noteCount) : nil
    }

    var meanRMSVariation: Double? {
        noteCount > 0 ? sumRMSVariation / Double(noteCount) : nil
    }

    var meanVibratoRate: Double? {
        vibratoSamples > 0 ? sumVibratoRate / Double(vibratoSamples) : nil
    }

    var meanVibratoExtent: Double? {
        vibratoSamples > 0 ? sumVibratoExtent / Double(vibratoSamples) : nil
    }

    /// Taux de frames où une personne a été détectée (confiance posture).
    var detectionRate: Double? {
        framesAnalyzed > 0 ? Double(personDetectedFrames) / Double(framesAnalyzed) : nil
    }

    /// Taux d'échantillons de hauteur valides (confiance son).
    var validPitchRatio: Double? {
        pitchFrames > 0 ? Double(validPitchFrames) / Double(pitchFrames) : nil
    }

    func reset(startedAt: Date) {
        self.startedAt = startedAt
        endedAt = nil
        framesAnalyzed = 0
        personDetectedFrames = 0
        pitchFrames = 0
        validPitchFrames = 0
        soundingSeconds = 0
        frequencies.removeAll()
        noteCount = 0
        inTuneNotes = 0
        sumAbsCents = 0
        sumStability = 0
        sumHNR = 0
        sumCentroid = 0
        sumRMSVariation = 0
        noteCents.removeAll()
        noteStability.removeAll()
        bowFrames = 0
        bowGoodAngle = 0
        bowGoodZone = 0
        bowContactSum = 0
        bowAngleSum = 0
        bowSpeedSum = 0
        bowTastoFrames = 0
        bowMiddleFrames = 0
        bowBridgeFrames = 0
        bowDirectionChanges = 0
        vibratoSamples = 0
        sumVibratoRate = 0
        sumVibratoExtent = 0
        articulationCounts = [:]
        motionJerk = nil
        motionStillness = nil
        motionSamples = 0
        handFrames = 0
        handDetectedFrames = 0
        handValidFrames = 0
        handAngleSum = 0
        handSignedAngleSum = 0
        handAngleMax = 0
        handFingerSpeedSum = 0
        handPresserConfidenceSum = 0
        handThumbFrames = 0
        handRuleSeconds = [:]
        handRuleOccurrences = [:]
        handRuleActive = [:]
        handLastSampleAt = nil
        positionSamples.removeAll()
    }

    /// Accumule une frame main gauche. Les règles A17/A19 sont des indicateurs
    /// de rapport (jamais des alertes temps réel) ; A18 reste une hypothèse.
    func addHand(_ metrics: LeftHandMetrics) {
        handFrames += 1
        handDetectedFrames += 1
        let now = metrics.timestamp
        let delta = handLastSampleAt.map { min(max(now - $0, 0), 0.5) } ?? 0
        handLastSampleAt = now

        if metrics.valid {
            handValidFrames += 1
            if let angle = metrics.handAngleDegrees {
                handAngleSum += angle
                handAngleMax = max(handAngleMax, angle)
            }
            if let signed = metrics.signedHandAngleDegrees {
                handSignedAngleSum += signed
            }
            if let speed = metrics.fingerSpeed {
                handFingerSpeedSum += speed
            }
            handPresserConfidenceSum += metrics.presserConfidence
            if metrics.thumbHypothesis { handThumbFrames += 1 }
        }

        for (ruleID, active) in metrics.flags {
            let wasActive = handRuleActive[ruleID] ?? false
            if active {
                handRuleSeconds[ruleID, default: 0] += delta
                if !wasActive {
                    handRuleOccurrences[ruleID, default: 0] += 1
                }
            }
            handRuleActive[ruleID] = active
        }
    }

    /// Compte une frame sans main détectée, pour que le taux de détection
    /// reste honnête (aucune métrique inventée).
    func addHandMiss(timestamp: TimeInterval) {
        handFrames += 1
        handLastSampleAt = timestamp
    }

    /// A20 : le coude ne guide pas le déplacement. Événement ponctuel, pas une
    /// alerte temps réel.
    func addHandShift(elbowMobility: Double, threshold: Double) {
        guard elbowMobility < threshold else { return }
        handRuleOccurrences["A20", default: 0] += 1
        handRuleSeconds["A20", default: 0] += 0.5
    }

    /// Accumule une frame d'archet vectorisée.
    func addBow(_ evaluation: BowEvaluation, vector: BowVector, directionChanges: Int) {
        bowFrames += 1
        if evaluation.angleOK { bowGoodAngle += 1 }
        if evaluation.zoneOK { bowGoodZone += 1 }
        bowContactSum += evaluation.contact
        bowAngleSum += evaluation.angleDeviation
        bowSpeedSum += vector.speed
        switch vector.zone {
        case .fingerboard: bowTastoFrames += 1
        case .middle: bowMiddleFrames += 1
        case .bridge: bowBridgeFrames += 1
        }
        bowDirectionChanges = max(bowDirectionChanges, directionChanges)
    }

    func bowRecord() -> BowRecord? {
        guard bowFrames > 0 else { return nil }
        let total = Double(max(1, bowFrames))
        return BowRecord(
            frames: bowFrames,
            goodAngle: bowGoodAngle,
            goodZone: bowGoodZone,
            meanAngleDeviation: bowAngleSum / total,
            meanContact: bowContactSum / total,
            meanSpeed: bowSpeedSum / total,
            tastoRatio: Double(bowTastoFrames) / total,
            middleRatio: Double(bowMiddleFrames) / total,
            ponticelloRatio: Double(bowBridgeFrames) / total,
            directionChanges: bowDirectionChanges
        )
    }

    func addPosition(_ record: NotePositionRecord) {
        positionSamples.append(record)
    }

    func handRecord() -> HandRecord? {
        guard handFrames > 0 else { return nil }
        let valid = max(1, handValidFrames)
        let rules = ["A17", "A18", "A19", "A20"].map { ruleID in
            HandRuleRecord(
                ruleID: ruleID,
                title: PostureRules.handRuleTitle(for: ruleID),
                seconds: handRuleSeconds[ruleID] ?? 0,
                occurrences: handRuleOccurrences[ruleID] ?? 0,
                confidence: ruleID == "A18" ? "hypothèse" : nil
            )
        }
        return HandRecord(
            frames: handFrames,
            validFrames: handValidFrames,
            meanAngleDegrees: handValidFrames > 0 ? handAngleSum / Double(valid) : nil,
            meanSignedAngleDegrees: handValidFrames > 0 ? handSignedAngleSum / Double(valid) : nil,
            maxAngleDegrees: handValidFrames > 0 ? handAngleMax : nil,
            meanFingerSpeed: handValidFrames > 0 ? handFingerSpeedSum / Double(valid) : nil,
            meanPresserConfidence: handValidFrames > 0 ? handPresserConfidenceSum / Double(valid) : nil,
            thumbHypothesisRatio: handValidFrames > 0 ? Double(handThumbFrames) / Double(valid) : nil,
            rules: rules,
            detectedFrames: handDetectedFrames
        )
    }

    func addNote(_ event: NoteEvent) {
        noteCount += 1
        sumAbsCents += abs(event.centsToNearest)
        sumStability += event.stabilityCents
        sumHNR += event.hnr
        sumCentroid += event.centroid
        sumRMSVariation += event.rmsVariation
        noteCents.append(event.centsToNearest)
        noteStability.append(event.stabilityCents)
        if let rate = event.vibratoRate, let extent = event.vibratoExtent {
            vibratoSamples += 1
            sumVibratoRate += rate
            sumVibratoExtent += extent
        }
        if abs(event.centsToNearest) <= 25 {
            inTuneNotes += 1
        }
    }

    func addArticulation(_ name: String) {
        articulationCounts[name, default: 0] += 1
    }

    func addFrequency(_ frequency: Double) {
        frequencies.append(frequency)
        if frequencies.count > 60_000 {
            frequencies.removeFirst(10_000)
        }
    }

    var medianFrequency: Double? {
        guard !frequencies.isEmpty else { return nil }
        let sorted = frequencies.sorted()
        return sorted[sorted.count / 2]
    }
}
