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
    var confidence: Double = 0
    var isOpenString = false
    var direction: ShiftDirection = .same
    var isShift = false
    var fromPosition: Int?
    var fromFinger: Int?
    var cameraHint: Int?
    var source = "audio"
}

/// Fusionne les candidats audio (corde × position × doigt) avec l'indice
/// caméra (P14) et la continuité de la main. La corde à vide est traitée
/// comme un choix (doigt 0), jamais comme une erreur.
///
/// Modèle simplifié : en 1re position, les doigts 1-4 sont à 2, 4, 5 et 7
/// demi-tons de la corde à vide ; chaque position supérieure décale l'ensemble
/// d'un demi-ton. La résolution annoncée est d'environ ±1 position.
final class PositionTracker {
    private struct Candidate {
        let stringMidi: Int
        let position: Int
        let finger: Int
        let midi: Double
    }

    private let openStrings = [36, 43, 50, 57] // C2, G2, D3, A3
    private let firstPositionOffsets = [2, 4, 5, 7]

    private var last: PositionAssignment?

    func reset() {
        last = nil
    }

    func assign(midi: Double, hand: LeftHandMetrics?, expected: FollowFeedback?) -> PositionAssignment {
        let candidates = makeCandidates()
            .filter { abs($0.midi - midi) <= 0.75 }

        guard !candidates.isEmpty else {
            let assignment = PositionAssignment(
                position: nil,
                finger: nil,
                stringMidi: nil,
                confidence: 0.1,
                direction: .same,
                isShift: false,
                fromPosition: last?.position,
                fromFinger: last?.finger,
                cameraHint: hand?.positionHint,
                source: "indéterminé"
            )
            last = assignment
            return assignment
        }

        let hint = hand?.positionHint
        let hintConfidence = hand?.positionHintConfidence ?? 0
        let presser = hand?.presserFinger
        let presserConfidence = hand?.presserConfidence ?? 0
        let expectedMidi = expected?.expectedMidi

        var scored: [(candidate: Candidate, score: Double)] = []
        for candidate in candidates {
            var score = -abs(candidate.midi - midi) * 4.0
            score -= 0.04 * Double(candidate.position - 1)

            if candidate.finger == 0 {
                // Une corde à vide n'est pas un « saut de position » : elle ne
                // subit pas la pénalité de continuité de la main.
                score += 0.12
                if hand?.valid == true { score -= 0.08 }
            } else if let lastPosition = last?.position {
                score -= 0.30 * Double(abs(candidate.position - lastPosition))
                if candidate.stringMidi == last?.stringMidi {
                    score += 0.20
                }
                if candidate.finger == last?.finger {
                    score += 0.04
                }
            }

            if candidate.finger > 0 {
                if let hint, hintConfidence > 0.15 {
                    score -= 0.28 * Double(abs(candidate.position - hint))
                }

                if let presser, presserConfidence > 0.25 {
                    score += candidate.finger == presser ? 0.30 : -0.10
                }
            }

            if let expectedMidi, abs(candidate.midi - Double(expectedMidi)) < 0.51 {
                score += 0.25
            }

            scored.append((candidate, score))
        }

        scored.sort { $0.score > $1.score }
        let best = scored[0]
        let second = scored.dropFirst().first
        let margin = second.map { best.score - $0.score } ?? 1.0
        var confidence = 1 / (1 + exp(-(margin - 0.05) * 5))
        confidence *= hand?.valid == true ? 0.88 : 0.66
        if let expectedMidi, abs(best.candidate.midi - Double(expectedMidi)) < 0.51 {
            confidence += 0.08
        }
        confidence = max(0.15, min(0.98, confidence))

        let isOpen = best.candidate.finger == 0
        let direction: ShiftDirection
        if isOpen {
            direction = .same
        } else if let previous = last?.position {
            if best.candidate.position > previous { direction = .up }
            else if best.candidate.position < previous { direction = .down }
            else { direction = .same }
        } else {
            direction = .same
        }

        let assignment = PositionAssignment(
            // Une corde à vide ne définit pas de position de main : ne pas
            // inventer un numéro de position ni un déplacement.
            position: isOpen ? nil : best.candidate.position,
            finger: best.candidate.finger,
            stringMidi: best.candidate.stringMidi,
            confidence: confidence,
            isOpenString: isOpen,
            direction: direction,
            isShift: !isOpen && last?.position != nil && best.candidate.position != last?.position,
            fromPosition: isOpen ? nil : last?.position,
            fromFinger: isOpen ? nil : last?.finger,
            cameraHint: hint,
            source: hand?.valid == true ? "caméra + audio" : "audio"
        )
        last = assignment
        return assignment
    }

    private func makeCandidates() -> [Candidate] {
        var candidates: [Candidate] = []
        for open in openStrings {
            candidates.append(Candidate(stringMidi: open, position: 1, finger: 0, midi: Double(open)))
            for position in 1...7 {
                for (index, offset) in firstPositionOffsets.enumerated() {
                    let midi = Double(open + offset + (position - 1))
                    candidates.append(
                        Candidate(
                            stringMidi: open,
                            position: position,
                            finger: index + 1,
                            midi: midi
                        )
                    )
                }
            }
        }
        return candidates
    }
}

// MARK: - Agrégats pour le rapport et le profil

struct PositionAggregate: Identifiable {
    let position: Int
    let finger: Int
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

    var id: String {
        "\(fromPosition ?? 0)-\(position)-\(finger)-\(direction.rawValue)"
    }

    var label: String {
        let fingerText = finger == 0 ? "corde à vide" : "\(finger)e doigt"
        if let fromPosition, fromPosition != position {
            return "\(fromPosition)e → \(position)e position · \(fingerText) · \(direction.rawValue)"
        }
        return "\(position)e position · \(fingerText)"
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
            let key = "\(note.fromPosition ?? 0)-\(position)-\(finger)-\(direction.rawValue)"
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
                direction: direction,
                fromPosition: first.fromPosition,
                count: samples.count,
                meanCents: cents.reduce(0, +) / Double(max(1, cents.count)),
                meanAbsCents: cents.map(abs).reduce(0, +) / Double(max(1, cents.count)),
                glideCount: glides.count,
                meanGlideMs: glides.isEmpty ? nil : glides.reduce(0, +) / Double(glides.count),
                meanGlideSlope: slopes.isEmpty ? nil : slopes.reduce(0, +) / Double(slopes.count),
                parasiteCount: parasites,
                parasiteRatio: shiftCount > 0 ? Double(parasites) / Double(shiftCount) : nil
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
