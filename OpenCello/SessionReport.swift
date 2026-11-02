import Foundation

/// Statistiques de séance et génération du rapport Markdown.
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
    var vibratoSamples = 0
    var sumVibratoRate = 0.0
    var sumVibratoExtent = 0.0
    var articulationCounts: [String: Int] = [:]
    var motionJerk: Double?
    var motionStillness: Double?
    var motionSamples = 0

    var meanAbsCents: Double {
        noteCount > 0 ? sumAbsCents / Double(noteCount) : 0
    }

    var meanStability: Double {
        noteCount > 0 ? sumStability / Double(noteCount) : 0
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
        vibratoSamples = 0
        sumVibratoRate = 0
        sumVibratoExtent = 0
        articulationCounts = [:]
        motionJerk = nil
        motionStillness = nil
        motionSamples = 0
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

    func markdown(lines: [RuleSummary], baseline: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        let start = startedAt ?? Date()
        let end = endedAt ?? Date()
        let duration = max(0, end.timeIntervalSince(start))
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let sortedLines = lines.sorted { $0.totalBadSeconds > $1.totalBadSeconds }

        var postureTable = "| Repère | Temps en alerte | Occurrences |\n|---|---|---|\n"
        for line in sortedLines {
            postureTable += String(format: "| %@ | %.1f s | %d |\n", line.title, line.totalBadSeconds, line.occurrences)
        }

        let detectionRate = framesAnalyzed > 0
            ? Int(round(Double(personDetectedFrames) / Double(framesAnalyzed) * 100))
            : 0

        let medianText: String
        if let median = medianFrequency {
            let note = NoteNamer.note(for: median)
            medianText = String(format: "%@%d (%.1f Hz)", note.name, note.octave, median)
        } else {
            medianText = "aucune note stable détectée"
        }

        let soundingRatio = duration > 0 ? Int(round(soundingSeconds / duration * 100)) : 0

        var noteSection = ""
        if noteCount > 0 {
            let inTuneRatio = Int(round(Double(inTuneNotes) / Double(noteCount) * 100))
            noteSection = """

            ### Analyse par note
            - Notes analysées : \(noteCount)
            - Notes justes (≤ 25 cents) : \(inTuneRatio) %
            - Écart moyen à la note tempérée : \(String(format: "%.1f", sumAbsCents / Double(noteCount))) cents
            - Stabilité moyenne (écart-type) : \(String(format: "%.1f", sumStability / Double(noteCount))) cents
            - HNR moyen : \(String(format: "%.1f", sumHNR / Double(noteCount))) dB
            - Centroïde spectral moyen : \(String(format: "%.0f", sumCentroid / Double(noteCount))) Hz
            - Variation RMS moyenne : \(String(format: "%.0f", sumRMSVariation / Double(noteCount) * 100)) %
            """
        }

        var bowSection = ""
        if bowFrames > 0 {
            let angleRatio = Int(round(Double(bowGoodAngle) / Double(bowFrames) * 100))
            let zoneRatio = Int(round(Double(bowGoodZone) / Double(bowFrames) * 100))
            bowSection = """

            ## Archet (profil)
            - Frames analysés : \(bowFrames)
            - Angle conforme (±10°) : \(angleRatio) %
            - Zone de contact conforme (10-90 %) : \(zoneRatio) %
            """
        }

        var vibratoSection = ""
        if vibratoSamples > 0 {
            vibratoSection = String(
                format: "  - Vibrato moyen : %.1f Hz · amplitude moyenne %.0f cents (sur %d notes)",
                sumVibratoRate / Double(vibratoSamples),
                sumVibratoExtent / Double(vibratoSamples),
                vibratoSamples
            )
        }

        var articulationSection = ""
        if !articulationCounts.isEmpty {
            let lines = articulationCounts
                .sorted { $0.value > $1.value }
                .map { "- \($0.key) : \($0.value)" }
                .joined(separator: "\n")
            articulationSection = """

            ## Articulations (heuristique)
            \(lines)

            > Classification indicative, non validée sur un jeu de données de référence.
            """
        }

        var motionSection = ""
        if motionSamples > 0, let jerk = motionJerk, let stillness = motionStillness {
            motionSection = String(
                format: """

                ## Fluidité du geste (indicatif)
                - Échantillons : %d
                - Jerk moyen : %.2f
                - Mobilité tête/buste : %.4f

                > Indicateurs non calibrés sur un panel de musiciens ; à interpréter avec prudence.
                """,
                motionSamples,
                jerk,
                stillness
            )
        }

        var recommendations: [String] = []
        for line in sortedLines.prefix(3) where line.totalBadSeconds > 3 {
            recommendations.append("- **\(line.title)** : \(exerciseHint(for: line.id))")
        }
        if recommendations.isEmpty {
            recommendations.append("- Aucun axe critique détecté cette fois-ci. Continuez avec des sons filés et une écoute active.")
        }

        return """
        # Rapport de séance — OpenCello

        **Date** : \(formatter.string(from: start))
        **Durée** : \(minutes) min \(seconds) s
        **Détection posture** : \(detectionRate) % des frames analysées

        ## Posture (baseline personnelle)

        \(baseline)

        \(postureTable)

        ## Son

        - Temps sonore : \(soundingRatio) % de la séance
        - Hauteur médiane détectée : \(medianText)
        - Échantillons de hauteur : \(validPitchFrames) valides / \(pitchFrames)
        - Règles : une erreur doit persister 5 s ; deux alertes maximum ; 20 s de repos entre deux alertes.
        \(noteSection)
        \(vibratoSection)
        \(bowSection)
        \(articulationSection)
        \(motionSection)

        ## Axes prioritaires et exercices

        \(recommendations.joined(separator: "\n"))

        ## Rappel

        Ce rapport est un outil de travail, pas un diagnostic médical. Les mesures sont estimées par caméra et microphone et peuvent comporter des erreurs (éclairage, angle, bruit). Signalez les faux positifs dans l'app.

        > Généré localement par OpenCello. Aucune donnée n'a quitté ce Mac.
        """
    }

    func pieceMarkdown(title: String, stats: PieceStats, bpm: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        let start = stats.startedAt ?? Date()
        let duration = max(0, Date().timeIntervalSince(start))
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let matchedRatio = stats.totalNotes > 0
            ? Int(round(Double(stats.matched) / Double(stats.totalNotes) * 100))
            : 0
        let inTuneRatio = Int(round(stats.inTuneRatio * 100))
        let tempoText = stats.estimatedTempo.map { String(format: "%.0f BPM", $0) } ?? "—"

        var advice: [String] = []
        if stats.matched > 0, stats.meanAbsCents > 25 {
            advice.append("- **Justesse** : travaillez la gamme lentement avec un bourdon (E4-01) et vérifiez chaque note à la corde à vide (E4-03).")
        }
        if stats.rhythmSamples > 0, stats.meanAbsRhythmMs > 150 {
            advice.append("- **Rythme** : ralentissez le tempo (métronome) et travaillez par cellules de 2 mesures ; le suivi indique un écart moyen de \(Int(stats.meanAbsRhythmMs)) ms.")
        }
        if stats.outOfScore > max(3, stats.matched / 5) {
            advice.append("- **Continuité** : beaucoup de notes hors partition — vérifiez la partie choisie (violoncelle) et le tempo de référence.")
        }
        if advice.isEmpty {
            advice.append("- Séance cohérente avec la partition. Continuez au tempo cible puis augmentez progressivement.")
        }

        return """
        # Rapport « Morceau » — \(title)

        **Date** : \(formatter.string(from: start))
        **Durée** : \(minutes) min \(seconds) s
        **Tempo de référence** : \(Int(bpm)) BPM · **Tempo estimé** : \(tempoText)

        ## Suivi de partition

        - Notes attendues (partie) : \(stats.totalNotes)
        - Notes reconnues : \(stats.matched) (\(matchedRatio) %)
        - Notes justes (≤ 25 cents) : \(inTuneRatio) %
        - Écart moyen de justesse : \(String(format: "%.1f", stats.meanAbsCents)) cents
        - Écart rythmique moyen : \(String(format: "%.0f", stats.meanAbsRhythmMs)) ms
        - Notes hors partition : \(stats.outOfScore)

        ## Conseils

        \(advice.joined(separator: "\n"))

        ## Rappel

        Le suivi compare chaque note détectée à la note attendue de la partition importée. Il dépend de la qualité de la détection de hauteur et de la partie choisie. Ce rapport est un outil de travail, pas un diagnostic.

        > Généré localement par OpenCello. Aucune donnée n'a quitté ce Mac.
        """
    }

    private func exerciseHint(for ruleID: String) -> String {
        switch ruleID {
        case "A1":
            return "Chin tucks et hauteur du pupitre (exercice E1-03)."
        case "A2":
            return "Roulements d'épaules et relâchement du cou (E1-02) ; vérifiez la pique et la chaise."
        case "A3":
            return "Wall slides / ouverture du buste (E1-04) ; sternum levé, omoplates basses."
        case "A4":
            return "Laissez peser le coude droit ; étirement du trapèze supérieur (E1-02)."
        default:
            return "Exercices de détente et de posture (voir docs/06)."
        }
    }
}
