import Foundation

// MARK: - Modèle de partition

struct ScoreNote: Identifiable {
    let id = UUID()
    var midi: Int
    var onsetBeats: Double
    var durationBeats: Double
    var measureIndex: Int
    var measureStartBeats: Double = 0
    /// Glissando/portamento écrit dans le MusicXML (technique volontaire).
    var glissando: Bool = false
    /// Doigté écrit (`<fingering>`), référence facultative : l'app mesure le
    /// doigté réel et ne l'impose pas.
    var fingering: Int? = nil
}

struct ScorePart: Identifiable {
    let id = UUID()
    var name: String
    var notes: [ScoreNote]
}

struct Score {
    var title: String
    var composer: String?
    var tempo: Double?
    var parts: [ScorePart]

    var defaultPartIndex: Int {
        if let index = parts.firstIndex(where: { part in
            let name = part.name.lowercased()
            return name.contains("cello") || name.contains("violoncelle") || name.contains("violoncello")
        }) {
            return index
        }
        if let index = parts.firstIndex(where: { !$0.notes.isEmpty }) {
            return index
        }
        return 0
    }
}

enum MusicXMLError: LocalizedError {
    case invalidXML
    case noNotes

    var errorDescription: String? {
        switch self {
        case .invalidXML: return "Fichier MusicXML invalide ou illisible."
        case .noNotes: return "Aucune note exploitable dans cette partition."
        }
    }
}

// MARK: - Parser MusicXML (sous-ensemble partwise)

/// Parse un fichier MusicXML « score-partwise » : notes, hauteurs, divisions,
/// silences, accords, liaisons, tempo. Suffisant pour le suivi de partition.
final class MusicXMLParser: NSObject, XMLParserDelegate {
    private enum Capture {
        case none
        case backup
        case forward
    }

    private struct RawNote {
        var midi: Int
        var onset: Int
        var duration: Int
        var measure: Int
        var measureStart: Int = 0
        var isRest: Bool
        var tieStart: Bool
        var tieStop: Bool
        var glissando: Bool = false
        var fingering: Int? = nil
    }

    private struct PartAccumulator {
        var name: String
        var notes: [RawNote] = []
    }

    private var title = ""
    private var composer: String?
    private var tempo: Double?
    private var divisions = 1
    private var currentTime = 0
    private var currentMeasure = 0
    private var currentMeasureStart = 0
    private var capture: Capture = .none
    private var currentElement = ""
    private var text = ""
    private var partNames: [String] = []
    private var inPartList = false
    private var parts: [PartAccumulator] = []
    private var currentPartIndex = -1
    private var currentNote: RawNote?
    private var pendingStep = ""
    private var pendingAlter = 0
    private var pendingOctave = 4
    private var pendingDuration = 0
    private var pendingChord = false
    private var pendingGrace = false
    private var pendingRest = false
    private var pendingTieStart = false
    private var pendingTieStop = false
    private var pendingGlissando = false
    private var pendingFingering: Int?
    private var creatorIsComposer = false
    private var lastNoteOnset = 0
    private var failed = false

    static func parse(data: Data) throws -> Score {
        let delegate = MusicXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        let success = parser.parse()
        guard success, !delegate.failed else { throw MusicXMLError.invalidXML }
        return try delegate.buildScore()
    }

    private func buildScore() throws -> Score {
        let parsedParts: [ScorePart] = parts.map { accumulator in
            let merged = mergeTies(accumulator.notes)
            let notes = merged
                .filter { !$0.isRest }
                .map { raw in
                    ScoreNote(
                        midi: raw.midi,
                        onsetBeats: Double(raw.onset) / Double(divisions),
                        durationBeats: Double(raw.duration) / Double(divisions),
                        measureIndex: raw.measure,
                        measureStartBeats: Double(raw.measureStart) / Double(divisions),
                        glissando: raw.glissando,
                        fingering: raw.fingering
                    )
                }
            return ScorePart(name: accumulator.name, notes: notes)
        }

        guard parsedParts.contains(where: { !$0.notes.isEmpty }) else {
            throw MusicXMLError.noNotes
        }

        return Score(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Partition sans titre" : title,
            composer: composer,
            tempo: tempo,
            parts: parsedParts
        )
    }

    private func mergeTies(_ notes: [RawNote]) -> [RawNote] {
        var result: [RawNote] = []
        var openTies: [Int: Int] = [:]

        for note in notes {
            if note.tieStop, let index = openTies[note.midi] {
                result[index].duration += note.duration
                if !note.tieStart {
                    openTies[note.midi] = nil
                }
            } else {
                result.append(note)
                if note.tieStart {
                    openTies[note.midi] = result.count - 1
                }
            }
        }
        return result
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        text = ""

        switch elementName {
        case "part-list":
            inPartList = true

        case "part":
            currentTime = 0
            currentMeasure = 0
            lastNoteOnset = 0
            let name = parts.count < partNames.count ? partNames[parts.count] : "Partie \(parts.count + 1)"
            parts.append(PartAccumulator(name: name))
            currentPartIndex = parts.count - 1

        case "measure":
            currentMeasure += 1
            currentMeasureStart = currentTime

        case "note":
            currentNote = RawNote(midi: 0, onset: 0, duration: 0, measure: currentMeasure, measureStart: currentMeasureStart, isRest: false, tieStart: false, tieStop: false)
            pendingStep = ""
            pendingAlter = 0
            pendingOctave = 4
            pendingDuration = 0
            pendingChord = false
            pendingGrace = false
            pendingRest = false
            pendingTieStart = false
            pendingTieStop = false
            pendingGlissando = false
            pendingFingering = nil

        case "glissando", "slide":
            pendingGlissando = true

        case "rest":
            pendingRest = true

        case "chord":
            pendingChord = true

        case "grace":
            pendingGrace = true

        case "tie":
            switch attributeDict["type"] {
            case "start": pendingTieStart = true
            case "stop": pendingTieStop = true
            default: break
            }

        case "backup":
            capture = .backup
            pendingDuration = 0

        case "forward":
            capture = .forward
            pendingDuration = 0

        case "sound":
            if let value = attributeDict["tempo"], let bpm = Double(value) {
                tempo = bpm
            }

        case "creator":
            creatorIsComposer = (attributeDict["type"] == "composer")

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "part-list":
            inPartList = false

        case "part-name":
            if inPartList {
                partNames.append(value)
            }

        case "work-title", "movement-title":
            if title.isEmpty { title = value }

        case "creator":
            if creatorIsComposer, composer == nil { composer = value }

        case "divisions":
            if let number = Int(value) { divisions = max(1, number) }

        case "step":
            pendingStep = value

        case "alter":
            pendingAlter = Int(value) ?? 0

        case "octave":
            pendingOctave = Int(value) ?? 4

        case "duration":
            let number = Int(value) ?? 0
            switch capture {
            case .backup:
                currentTime = max(0, currentTime - number)
                capture = .none
            case .forward:
                currentTime += number
                capture = .none
            case .none:
                pendingDuration = number
            }

        case "fingering":
            pendingFingering = Int(value)

        case "note":
            finalizeNote()

        case "part":
            currentPartIndex = -1

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        failed = true
    }

    // MARK: Note

    private func finalizeNote() {
        defer {
            currentNote = nil
            pendingDuration = 0
        }

        guard var note = currentNote, !pendingGrace else { return }
        note.isRest = pendingRest

        if !pendingChord {
            note.onset = currentTime
            currentTime += pendingDuration
            lastNoteOnset = note.onset
        } else {
            note.onset = lastNoteOnset
        }

        guard !pendingRest else { return }

        let semitones: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let semitone = semitones[pendingStep.uppercased()] else { return }

        note.midi = 12 * (pendingOctave + 1) + semitone + pendingAlter
        note.duration = pendingDuration
        note.measureStart = currentMeasureStart
        note.tieStart = pendingTieStart
        note.tieStop = pendingTieStop
        note.glissando = pendingGlissando
        note.fingering = pendingFingering

        if currentPartIndex >= 0, currentPartIndex < parts.count {
            parts[currentPartIndex].notes.append(note)
        }
    }
}
