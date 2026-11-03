import Foundation

enum ShiftDirection: String, Codable {
    case up = "montée"
    case down = "descente"
    case same = "sur place"

    var preposition: String {
        switch self {
        case .up: return "en montant"
        case .down: return "en descendant"
        case .same: return "sur place"
        }
    }
}

/// Position + doigt estimés pour une note.
struct PositionAssignment {
    var position: Int?
    var finger: Int?
    var stringMidi: Int?
    var stringNumber: Int? = nil
    var confidence: Double = 0
    var isOpenString = false
    var exact = false
    var alternatives: [String] = []
    var isThumbPosition = false
    var direction: ShiftDirection = .same
    var isShift = false
    var fromPosition: Int?
    var fromFinger: Int?
    var cameraHint: Int?
    var source = "audio"

    var stringText: String {
        switch stringNumber {
        case 1: return "la"
        case 2: return "ré"
        case 3: return "sol"
        case 4: return "do"
        default: return "corde —"
        }
    }

    var fingerText: String {
        guard let finger else { return "doigt —" }
        switch finger {
        case 0: return "corde à vide"
        case 5: return "pouce"
        default: return "\(finger)e doigt"
        }
    }

    var positionText: String {
        guard let position else { return "position —" }
        return isThumbPosition ? "pouce \(position)e" : "\(position)e position"
    }
}

/// Déduit la position **exactement** dès que la corde et le doigt sont connus :
/// position = note − corde à vide − décalage du doigt + 1.
///
/// Modèle : cordes 1 = la (A3), 2 = ré (D3), 3 = sol (G2), 4 = do (C2) ;
/// en 1re position les doigts 1-4 sont à 2, 4, 5 et 7 demi-tons de la corde
/// à vide, chaque position supérieure décale l'ensemble d'un demi-ton.
/// Le pouce (doigt 5) est traité comme un sillet mobile en position haute
/// (7e et au-delà), avec les mêmes décalages pour les doigts au-dessus.
final class PositionTracker {
    private struct Candidate {
        let stringNumber: Int
        let stringMidi: Int
        let finger: Int
        let position: Int
        let midi: Double
    }

    // 1 = la (A3), 2 = ré (D3), 3 = sol (G2), 4 = do (C2) — notation MusicXML.
    private let strings: [(number: Int, midi: Int)] = [
        (1, 57),
        (2, 50),
        (3, 43),
        (4, 36)
    ]
    private let fingerOffsets = [2, 4, 5, 7] // doigts 1-4 en 1re position

    private var last: PositionAssignment?

    func reset() {
        last = nil
    }

    func assign(midi: Double, hand: LeftHandMetrics?, expected: FollowFeedback?) -> PositionAssignment {
        let target = midi.rounded()
        let candidates = makeCandidates().filter { abs($0.midi - target) <= 0.6 }

        guard !candidates.isEmpty else {
            let assignment = PositionAssignment(
                position: nil,
                finger: hand?.presserFinger,
                stringMidi: nil,
                stringNumber: nil,
                confidence: 0.1,
                exact: false,
                alternatives: [],
                direction: .same,
                isShift: false,
                fromPosition: last?.position,
                fromFinger: last?.finger,
                cameraHint: hand?.positionHint,
                source: "note hors modèle"
            )
            last = assignment
            return assignment
        }

        let hint = hand?.positionHint
        let hintConfidence = hand?.positionHintConfidence ?? 0
        let presser = hand?.presserFinger
        let presserConfidence = hand?.presserConfidence ?? 0
        let expectedString = expected?.expectedStringNumber
        let expectedFinger = expected?.expectedFingering
        let expectedMidi = expected?.expectedMidi

        func score(_ candidate: Candidate) -> Double {
            var value = -abs(candidate.midi - target) * 10
            if let expectedString, candidate.stringNumber == expectedString {
                value += 4
            }
            if let expectedFinger, candidate.finger == expectedFinger {
                value += 3
            }
            if let presser, presserConfidence > 0.25 {
                value += candidate.finger == presser ? 4 : -1.5
            }
            if let hint, hintConfidence > 0.15 {
                value -= 0.35 * Double(abs(candidate.position - hint))
            }
            if let expectedMidi, abs(candidate.midi - Double(expectedMidi)) < 0.51 {
                value += 1
            }
            if candidate.finger == 0 {
                value += 0.5
                if let presser, presser != 0 { value -= 2 }
            }
            if candidate.finger == 5 {
                value += presser == 5 ? 3 : -1.5
                if candidate.position < 7 { value -= 2 }
            }
            if let lastPosition = last?.position, candidate.finger > 0 {
                value -= 0.15 * Double(abs(candidate.position - lastPosition))
                if candidate.stringNumber == last?.stringNumber { value += 0.4 }
            }
            return value
        }

        let scored = candidates
            .map { (candidate: $0, score: score($0)) }
            .sorted { $0.score > $1.score }
        let best = scored[0].candidate
        let secondScore = scored.dropFirst().first?.score
        let margin = secondScore.map { scored[0].score - $0 } ?? 5

        let stringKnown = expectedString != nil
        let fingerKnown = (presser != nil && presserConfidence > 0.35) || expectedFinger != nil
        let isOpen = best.finger == 0
        let cameraKnown = presser != nil && presserConfidence > 0.35 && hint != nil && hintConfidence > 0.2
        let cameraDistance = hint.map { abs(best.position - $0) } ?? 99
        let nextOtherString = scored.dropFirst().first {
            $0.candidate.stringNumber != best.stringNumber || $0.candidate.finger != best.finger
        }
        let nextPositionGap = nextOtherString.map { abs($0.candidate.position - best.position) } ?? 99
        let cameraExact = cameraKnown && !isOpen && cameraDistance <= 1
            && (nextPositionGap >= 3 || margin >= 3)
        let exact = (stringKnown && fingerKnown) || cameraExact

        var confidence: Double
        if exact {
            confidence = stringKnown && fingerKnown ? 0.97 : 0.92
        } else if margin > 2 {
            confidence = 0.85
        } else if margin > 0.8 {
            confidence = 0.7
        } else {
            confidence = 0.5
        }
        if !stringKnown { confidence *= 0.85 }
        if !fingerKnown { confidence *= 0.8 }
        confidence = max(0.2, min(0.99, confidence))

        let isThumb = best.finger == 5
        let direction: ShiftDirection
        if isOpen {
            direction = .same
        } else if let previous = last?.position {
            if best.position > previous { direction = .up }
            else if best.position < previous { direction = .down }
            else { direction = .same }
        } else {
            direction = .same
        }

        let alternatives: [String] = exact ? [] : scored.prefix(4).map { item in
            let candidate = item.candidate
            let stringName = stringName(for: candidate.stringNumber)
            let finger = candidate.finger == 0
                ? "corde à vide"
                : (candidate.finger == 5 ? "pouce" : "\(candidate.finger)e doigt")
            return "\(stringName) · \(finger) · \(candidate.position)e"
        }

        let source: String
        if exact && stringKnown && fingerKnown {
            source = "note + doigt + corde"
        } else if exact {
            source = "note + doigt + caméra"
        } else if stringKnown {
            source = "note + corde (doigt estimé)"
        } else if fingerKnown {
            source = "note + doigt (corde ambiguë)"
        } else {
            source = "audio + caméra"
        }

        let assignment = PositionAssignment(
            position: isOpen ? nil : best.position,
            finger: best.finger,
            stringMidi: best.stringMidi,
            stringNumber: best.stringNumber,
            confidence: confidence,
            isOpenString: isOpen,
            exact: exact,
            alternatives: alternatives,
            isThumbPosition: isThumb,
            direction: direction,
            isShift: !isOpen && last?.position != nil && best.position != last?.position,
            fromPosition: isOpen ? nil : last?.position,
            fromFinger: isOpen ? nil : last?.finger,
            cameraHint: hint,
            source: source
        )
        last = assignment
        return assignment
    }

    private func makeCandidates() -> [Candidate] {
        var candidates: [Candidate] = []
        for string in strings {
            candidates.append(
                Candidate(
                    stringNumber: string.number,
                    stringMidi: string.midi,
                    finger: 0,
                    position: 1,
                    midi: Double(string.midi)
                )
            )
            for position in 1...24 {
                for (index, offset) in fingerOffsets.enumerated() {
                    let midi = string.midi + offset + (position - 1)
                    if midi <= 108 {
                        candidates.append(
                            Candidate(
                                stringNumber: string.number,
                                stringMidi: string.midi,
                                finger: index + 1,
                                position: position,
                                midi: Double(midi)
                            )
                        )
                    }
                }
            }
            // Pouce : sillet mobile en position haute (7e et au-delà).
            for position in 7...24 {
                let midi = string.midi + (position - 1)
                if midi <= 108 {
                    candidates.append(
                        Candidate(
                            stringNumber: string.number,
                            stringMidi: string.midi,
                            finger: 5,
                            position: position,
                            midi: Double(midi)
                        )
                    )
                }
            }
        }
        return candidates
    }

    private func stringName(for number: Int) -> String {
        switch number {
        case 1: return "la"
        case 2: return "ré"
        case 3: return "sol"
        case 4: return "do"
        default: return "corde ?"
        }
    }
}

// MARK: - Agrégats pour le rapport et le profil

struct PositionAggregate: Identifiable {
    let position: Int
    let finger: Int
    let stringNumber: Int?
    let direction: ShiftDirection
    let fromPosition: Int?
    let count: Int
    let meanCents: Double
    let meanAbsCents: Double
    let glideCount: Int
    let meanGlideMs: Double?
    let meanGlideSlope: Double?
    let parasiteCount: Int
    let parasiteRatio: Double?
    let exactCount: Int

    var id: String {
        "\(stringNumber ?? 0)-\(fromPosition ?? 0)-\(position)-\(finger)-\(direction.rawValue)"
    }

    var label: String {
        let stringText: String
        switch stringNumber {
        case 1: stringText = "la · "
        case 2: stringText = "ré · "
        case 3: stringText = "sol · "
        case 4: stringText = "do · "
        default: stringText = ""
        }
        let fingerText = finger == 0 ? "corde à vide" : (finger == 5 ? "pouce" : "\(finger)e doigt")
        if let fromPosition, fromPosition != position {
            let positionText = finger == 5 ? "position du pouce \(position)e" : "\(fromPosition)e → \(position)e position"
            return "\(stringText)\(positionText) · \(fingerText) · \(direction.rawValue)"
        }
        let positionText = finger == 5 ? "position du pouce \(position)e" : "\(position)e position"
        return "\(stringText)\(positionText) · \(fingerText)"
    }
}

enum PositionAnalysis {
    static func aggregates(from notes: [NotePositionRecord], shiftsOnly: Bool = false) -> [PositionAggregate] {
        let filtered = notes.filter { note in
            note.position != nil && note.finger != nil && (!shiftsOnly || note.isShift)
        }
        var groups: [String: [NotePositionRecord]] = [:]
        for note in filtered {
            guard let position = note.position, let finger = note.finger else { continue }
            let direction = ShiftDirection(rawValue: note.direction ?? "") ?? .same
            let key = "\(note.stringNumber ?? 0)-\(note.fromPosition ?? 0)-\(position)-\(finger)-\(direction.rawValue)"
            groups[key, default: []].append(note)
        }

        return groups.values.compactMap { samples in
            guard let first = samples.first,
                  let position = first.position,
                  let finger = first.finger else { return nil }
            let direction = ShiftDirection(rawValue: first.direction ?? "") ?? .same
            let cents = samples.map(\.cents)
            let glides = samples.compactMap(\.glideMs).filter { $0 >= 80 }
            let slopes = samples.compactMap(\.glideSlope)
            let parasites = samples.filter {
                $0.isShift && !$0.isVoluntaryGlide && ($0.glideMs ?? 0) >= 150
            }.count
            let shiftCount = samples.filter(\.isShift).count
            return PositionAggregate(
                position: position,
                finger: finger,
                stringNumber: first.stringNumber,
                direction: direction,
                fromPosition: first.fromPosition,
                count: samples.count,
                meanCents: cents.reduce(0, +) / Double(max(1, cents.count)),
                meanAbsCents: cents.map(abs).reduce(0, +) / Double(max(1, cents.count)),
                glideCount: glides.count,
                meanGlideMs: glides.isEmpty ? nil : glides.reduce(0, +) / Double(glides.count),
                meanGlideSlope: slopes.isEmpty ? nil : slopes.reduce(0, +) / Double(slopes.count),
                parasiteCount: parasites,
                parasiteRatio: shiftCount > 0 ? Double(parasites) / Double(shiftCount) : nil,
                exactCount: samples.filter(\.exactPosition).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.meanAbsCents > rhs.meanAbsCents
        }
    }

    static func worstShift(from notes: [NotePositionRecord]) -> PositionAggregate? {
        aggregates(from: notes, shiftsOnly: true)
            .filter { $0.count >= 2 }
            .max { $0.meanAbsCents < $1.meanAbsCents }
    }

    static func parasiteGlideSummary(from notes: [NotePositionRecord]) -> (position: Int, parasite: Int, total: Int)? {
        let shifts = notes.filter(\.isShift)
        guard !shifts.isEmpty else { return nil }
        var totals: [Int: (parasite: Int, total: Int)] = [:]
        for note in shifts {
            guard let position = note.position else { continue }
            var item = totals[position] ?? (0, 0)
            item.total += 1
            if let glide = note.glideMs, glide >= 150, !note.isVoluntaryGlide {
                item.parasite += 1
            }
            totals[position] = item
        }
        return totals
            .map { (position: $0.key, parasite: $0.value.parasite, total: $0.value.total) }
            .filter { $0.parasite > 0 }
            .max { lhs, rhs in
                let lhsRatio = Double(lhs.parasite) / Double(max(1, lhs.total))
                let rhsRatio = Double(rhs.parasite) / Double(max(1, rhs.total))
                return lhsRatio < rhsRatio
            }
    }

    static func meanAbsCentsByPosition(from notes: [NotePositionRecord]) -> [(position: Int, cents: Double, count: Int)] {
        var groups: [Int: [Double]] = [:]
        for note in notes {
            guard let position = note.position else { continue }
            groups[position, default: []].append(abs(note.cents))
        }
        return groups
            .map { (position: $0.key, cents: $0.value.reduce(0, +) / Double($0.value.count), count: $0.value.count) }
            .sorted { $0.position < $1.position }
    }

    static func meanShiftDurationMs(from notes: [NotePositionRecord]) -> Double? {
        let sorted = notes.sorted { $0.onset < $1.onset }
        guard sorted.count > 1 else { return nil }

        var values: [Double] = []
        for index in 1..<sorted.count {
            let note = sorted[index]
            guard note.isShift else { continue }
            if let glide = note.glideMs, glide > 0 {
                values.append(glide)
            } else {
                let previous = sorted[index - 1]
                let gap = note.onset - (previous.onset + previous.duration)
                if gap > 0 { values.append(gap * 1000) }
            }
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
