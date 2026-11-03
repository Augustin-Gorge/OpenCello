import Foundation
import AppKit
import PDFKit
import SwiftUI

/// Export des rapports en PDF et JSON dans ~/Documents/OpenCello/Rapports.
enum ReportExporter {
    static func directory() -> URL? {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = documents.appendingPathComponent("OpenCello/Rapports", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func exportJSON(_ record: SessionRecord, to destination: URL? = nil) -> URL? {
        guard let directory = destination ?? directory() else { return nil }
        let url = directory.appendingPathComponent(fileName(for: record, ext: "json"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(record) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    static func exportPDF(_ record: SessionRecord, to destination: URL? = nil) -> URL? {
        guard let directory = destination ?? directory() else { return nil }
        let renderer = ImageRenderer(content: ReportPDFView(record: record).frame(width: 820))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }

        let document = PDFDocument()
        guard let page = PDFPage(image: image) else { return nil }
        document.insert(page, at: 0)
        let url = directory.appendingPathComponent(fileName(for: record, ext: "pdf"))
        return document.write(to: url) ? url : nil
    }

    @MainActor
    static func exportTeacherPack(_ record: SessionRecord) -> URL? {
        guard let base = directory() else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let pack = base
            .appendingPathComponent("Pack_Professeur_\(formatter.string(from: record.date))", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: pack, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        guard exportPDF(record, to: pack) != nil,
              exportJSON(record, to: pack) != nil else {
            return nil
        }

        let postureLines = record.posture
            .sorted { $0.seconds > $1.seconds }
            .map { "- \($0.title) : \(Int($0.seconds)) s en alerte, \($0.occurrences) occurrence(s)" }
            .joined(separator: "\n")

        let notes = """
        # Pack professeur — \(record.title)

        **Date** : \(formatter.string(from: record.date))
        **Mode** : \(record.mode)
        **Durée** : \(Int(record.duration / 60)) min

        ## Synthèse

        - Notes analysées : \(record.noteCount)
        - Notes justes : \(Int(record.inTuneRatio * 100)) %
        - Écart moyen : \(String(format: "%.0f", record.meanAbsCents)) cents
        - Stabilité moyenne : \(String(format: "%.0f", record.meanStability)) cents

        ## Posture

        \(postureLines.isEmpty ? "Aucune alerte posture enregistrée." : postureLines)

        \(handLines(record))

        \(positionLines(record))

        \(techniqueLines(record))

        ## Points à travailler

        - [ ] À compléter avec le professeur.
        - [ ] Choix des exercices prioritaires.

        ## Fichiers

        - Rapport PDF et données JSON joints dans ce dossier.
        - Généré localement par OpenCello ; aucune donnée n'a quitté le Mac.
        """

        let notesURL = pack.appendingPathComponent("notes_professeur.md")
        do {
            try notes.write(to: notesURL, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        return pack
    }

    static func exportAnonymized(_ records: [SessionRecord]) -> URL? {
        guard let directory = directory() else { return nil }

        struct AnonymizedPiece: Codable {
            let matched: Int
            let total: Int
            let inTune: Int
            let meanAbsCents: Double
            let meanAbsRhythmMs: Double
            let outOfScore: Int
        }

        struct AnonymizedRecord: Codable {
            let mode: String
            let duration: Double
            let postureSeconds: [String: Double]
            let noteCount: Int
            let inTuneNotes: Int
            let meanAbsCents: Double
            let meanStability: Double
            let bowGoodAngleRatio: Double?
            let bowGoodZoneRatio: Double?
            let piece: AnonymizedPiece?
            // v1.1 : agrégats seulement, aucune note ni titre de morceau.
            let handMeanAngleDegrees: Double?
            let handDetectionRate: Double?
            let handRuleSeconds: [String: Double]
            let positionSampleCount: Int
            let shiftCount: Int
            let meanShiftArrivalCents: Double?
            let piqueRegularity: Double?
            let parasiteGlides: Int
        }

        let anonymized: [AnonymizedRecord] = records.map { record in
            AnonymizedRecord(
                mode: record.mode,
                duration: record.duration,
                postureSeconds: Dictionary(
                    uniqueKeysWithValues: record.posture.map { ($0.ruleID, $0.seconds) }
                ),
                noteCount: record.noteCount,
                inTuneNotes: record.inTuneNotes,
                meanAbsCents: record.meanAbsCents,
                meanStability: record.meanStability,
                bowGoodAngleRatio: record.bow.map {
                    $0.frames > 0 ? Double($0.goodAngle) / Double($0.frames) : nil
                } ?? nil,
                bowGoodZoneRatio: record.bow.map {
                    $0.frames > 0 ? Double($0.goodZone) / Double($0.frames) : nil
                } ?? nil,
                piece: record.piece.map {
                    AnonymizedPiece(
                        matched: $0.matched,
                        total: $0.total,
                        inTune: $0.inTune,
                        meanAbsCents: $0.meanAbsCents,
                        meanAbsRhythmMs: $0.meanAbsRhythmMs,
                        outOfScore: $0.outOfScore
                    )
                },
                handMeanAngleDegrees: record.hand?.meanAngleDegrees,
                handDetectionRate: record.hand?.detectionRate,
                handRuleSeconds: Dictionary(
                    uniqueKeysWithValues: (record.hand?.rules ?? []).map { ($0.ruleID, $0.seconds) }
                ),
                positionSampleCount: record.positionStats?.samples.count ?? 0,
                shiftCount: record.positionStats?.shiftCount ?? 0,
                meanShiftArrivalCents: record.positionStats?.meanArrivalCents,
                piqueRegularity: record.technique?.piqueRegularity,
                parasiteGlides: record.technique?.parasiteGlides ?? 0
            )
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let url = directory.appendingPathComponent("etude_anonyme_\(formatter.string(from: Date())).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(anonymized) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func handLines(_ record: SessionRecord) -> String {
        guard let hand = record.hand, hand.frames > 0 else {
            return "## Main gauche\n\nAucune donnée main gauche (caméra indisponible ou main non détectée)."
        }
        var lines = ["## Main gauche", ""]
        if let rate = hand.detectionRate {
            lines.append("- Main détectée : \(Int(rate * 100)) % des frames")
        }
        if let angle = hand.meanAngleDegrees {
            lines.append(String(format: "- Angle main/avant-bras : %.0f° (max %.0f°)", angle, hand.maxAngleDegrees ?? angle))
        }
        if let ratio = hand.thumbHypothesisRatio, ratio > 0 {
            lines.append(String(format: "- Pouce crispé (hypothèse, A18) : %.0f %% des frames", ratio * 100))
        }
        for rule in hand.rules where rule.seconds > 1 || rule.occurrences > 0 {
            let confidence = rule.confidence != nil && !rule.title.lowercased().contains("hypothèse")
                ? " (\(rule.confidence!))"
                : ""
            lines.append(String(format: "- %@ : %.0f s, %d occurrence(s)%@", rule.title, rule.seconds, rule.occurrences, confidence))
        }
        return lines.joined(separator: "\n")
    }

    private static func positionLines(_ record: SessionRecord) -> String {
        guard let stats = record.positionStats, !stats.samples.isEmpty else {
            return "## Positions et déplacements\n\nAucune position estimée sur cette séance."
        }
        var lines = ["## Positions et déplacements", ""]
        lines.append("- Notes situées : \(stats.samples.filter { $0.position != nil }.count)/\(stats.samples.count)")
        lines.append("- Déplacements : \(stats.shiftCount)")
        if let arrival = stats.meanArrivalCents {
            lines.append(String(format: "- Justesse d'arrivée moyenne : %+.0f cents", arrival))
        }
        if let duration = stats.meanShiftDurationMs {
            lines.append(String(format: "- Durée moyenne de transition : %.0f ms", duration))
        }
        lines.append("- Glissés parasites : \(stats.parasiteGlides) · volontaires : \(stats.voluntaryGlides)")
        for aggregate in PositionAnalysis.aggregates(from: stats.samples).prefix(5) {
            let slope = aggregate.meanGlideSlope.map { String(format: ", pente %.0f cents/s", $0) } ?? ""
            let parasites = aggregate.parasiteRatio.map { String(format: ", parasites %.0f %%", $0 * 100) } ?? ""
            lines.append(String(format: "- %@ : %d note(s), écart moyen %.0f cents%@%@", aggregate.label, aggregate.count, aggregate.meanAbsCents, slope, parasites))
        }
        return lines.joined(separator: "\n")
    }

    private static func techniqueLines(_ record: SessionRecord) -> String {
        guard let technique = record.technique else {
            return "## Techniques particulières\n\nAucune technique particulière détectée."
        }
        var lines = ["## Techniques particulières", ""]
        if technique.piqueNotes > 0 {
            lines.append("- Piqué : \(technique.piqueNotes) notes, \(technique.piqueUnevenRuns) série(s) inégale(s)")
            if let regularity = technique.piqueRegularity {
                lines.append(String(format: "- Régularité des durées : %.0f %%", regularity * 100))
            }
        }
        if technique.glideShifts > 0 {
            lines.append(String(format: "- Glissés : %d déplacement(s), %.0f ms en moyenne, pente %.0f cents/s",
                                technique.glideShifts, technique.meanGlideMs ?? 0, technique.meanGlideSlope ?? 0))
            lines.append("- Volontaires : \(technique.voluntaryGlides) · parasites : \(technique.parasiteGlides)")
        }
        return lines.joined(separator: "\n")
    }

    static func openFolder() {
        guard let directory = directory() else { return }
        NSWorkspace.shared.open(directory)
    }

    private static func fileName(for record: SessionRecord, ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "seance_\(formatter.string(from: record.date)).\(ext)"
    }
}

struct ReportPDFView: View {
    let record: SessionRecord

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: record.date)
    }

    private var durationText: String {
        let total = Int(record.duration)
        return String(format: "%d min %02d s", total / 60, total % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rapport de séance — OpenCello")
                .font(.system(size: 26, weight: .bold))
            Text("\(record.mode) · \(record.title)")
                .font(.system(size: 15))
            Text("\(dateText) · \(durationText)")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Divider()

            if !record.posture.isEmpty {
                Text("Posture")
                    .font(.system(size: 16, weight: .semibold))
                ForEach(record.posture) { item in
                    HStack {
                        Text(item.title).font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.0f s en alerte · %d occurrence(s)", item.seconds, item.occurrences))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }

            Text("Son")
                .font(.system(size: 16, weight: .semibold))
            Text("Notes analysées : \(record.noteCount) · justes : \(Int(record.inTuneRatio * 100)) %")
                .font(.system(size: 12))
            Text(String(format: "Écart moyen : %.1f cents · stabilité moyenne : %.1f cents",
                        record.meanAbsCents, record.meanStability))
                .font(.system(size: 12))
            Text(String(format: "Temps sonore : %.0f s", record.soundingSeconds))
                .font(.system(size: 12))

            if let piece = record.piece {
                Text("Morceau")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(piece.matched)/\(piece.total) notes reconnues · justes : \(piece.inTune)")
                    .font(.system(size: 12))
                Text(String(format: "Justesse moyenne : %.1f cents · rythme moyen : %.0f ms · hors partition : %d",
                            piece.meanAbsCents, piece.meanAbsRhythmMs, piece.outOfScore))
                    .font(.system(size: 12))
            }

            if let bow = record.bow, bow.frames > 0 {
                Text("Archet (profil)")
                    .font(.system(size: 16, weight: .semibold))
                Text(String(format: "Angle conforme : %d %% · zone conforme : %d %% (%d frames)",
                            Int(Double(bow.goodAngle) / Double(bow.frames) * 100),
                            Int(Double(bow.goodZone) / Double(bow.frames) * 100),
                            bow.frames))
                    .font(.system(size: 12))
            }

            if let hand = record.hand, hand.frames > 0 {
                Text("Main gauche")
                    .font(.system(size: 16, weight: .semibold))
                if let rate = hand.detectionRate {
                    Text("Main détectée sur \(Int(rate * 100)) % des frames · \(hand.validFrames) frames exploitables")
                        .font(.system(size: 12))
                }
                if let angle = hand.meanAngleDegrees {
                    Text(String(format: "Angle main/avant-bras : %.0f° en moyenne (max %.0f°)",
                                angle, hand.maxAngleDegrees ?? angle))
                        .font(.system(size: 12))
                }
                if let ratio = hand.thumbHypothesisRatio, ratio > 0 {
                    Text(String(format: "Pouce crispé (hypothèse, A18) : %.0f %% des frames", ratio * 100))
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                ForEach(hand.rules.filter { $0.seconds > 1 || $0.occurrences > 0 }) { rule in
                    let confidence = rule.confidence != nil && !rule.title.lowercased().contains("hypothèse")
                        ? " (\(rule.confidence!))"
                        : ""
                    Text(String(format: "%@ : %.0f s · %d occurrence(s)%@",
                                rule.title, rule.seconds, rule.occurrences, confidence))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            if let stats = record.positionStats, !stats.samples.isEmpty {
                Text("Positions et déplacements")
                    .font(.system(size: 16, weight: .semibold))
                Text("Notes situées : \(stats.samples.filter { $0.position != nil }.count)/\(stats.samples.count) · déplacements : \(stats.shiftCount)")
                    .font(.system(size: 12))
                Text(String(format: "Arrivée moyenne : %@ · transition moyenne : %@ · glissés parasites : %d",
                            stats.meanArrivalCents.map { String(format: "%+.0f cents", $0) } ?? "—",
                            stats.meanShiftDurationMs.map { String(format: "%.0f ms", $0) } ?? "—",
                            stats.parasiteGlides))
                    .font(.system(size: 12))
                ForEach(PositionAnalysis.aggregates(from: stats.samples).prefix(5)) { aggregate in
                    Text(String(format: "%@ : %d note(s), écart moyen %.0f cents%@%@",
                                aggregate.label, aggregate.count, aggregate.meanAbsCents,
                                aggregate.meanGlideSlope.map { String(format: ", pente %.0f c/s", $0) } ?? "",
                                aggregate.parasiteRatio.map { String(format: ", parasites %.0f %%", $0 * 100) } ?? ""))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            if let technique = record.technique,
               technique.piqueNotes > 0 || technique.glideShifts > 0 {
                Text("Techniques particulières")
                    .font(.system(size: 16, weight: .semibold))
                if technique.piqueNotes > 0 {
                    Text("Piqué : \(technique.piqueNotes) notes · \(technique.piqueUnevenRuns) série(s) inégale(s)")
                        .font(.system(size: 12))
                }
                if technique.glideShifts > 0 {
                    Text(String(format: "Glissés : %d déplacement(s), %.0f ms en moyenne · pente %.0f cents/s · volontaires %d · parasites %d",
                                technique.glideShifts, technique.meanGlideMs ?? 0, technique.meanGlideSlope ?? 0,
                                technique.voluntaryGlides, technique.parasiteGlides))
                        .font(.system(size: 12))
                }
            }

            if let replays = record.replayMoments, !replays.isEmpty {
                Text("Replays pédagogiques")
                    .font(.system(size: 16, weight: .semibold))
                ForEach(replays) { moment in
                    Text("\(moment.title) — \(moment.detail)")
                        .font(.system(size: 11))
                    Text(moment.advice)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            Divider()

            Text("Outil de travail, pas un diagnostic médical. Les mesures sont estimées par caméra et microphone ; l'éclairage, l'angle et le bruit peuvent les affecter.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text("Généré localement par OpenCello. Aucune donnée n'a quitté ce Mac.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(40)
        .frame(width: 820, alignment: .leading)
        .background(Color.white)
        .foregroundColor(.black)
    }
}
