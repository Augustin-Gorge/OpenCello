import SwiftUI

/// Replay pédagogique : piano-roll reconstruit depuis les statistiques,
/// version jouée vs version corrigée synthétisée localement.
struct ReplayView: View {
    let moment: ReplayMoment
    @StateObject private var audio = ReplayAudioEngine()
    @Environment(\.dismiss) private var dismiss
    @State private var corrected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.title).font(.title2.bold())
                    Text(moment.detail).font(.callout).foregroundStyle(.secondary)
                    if let measure = moment.measure {
                        Text("Mesure \(measure)\(moment.beat.map { String(format: " · temps %.1f", $0) } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Fermer") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Text(moment.advice)
                .font(.callout)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

            Picker("Version", selection: $corrected) {
                Text("Ce que tu as fait").tag(false)
                Text("Ce que ça devrait être").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            ReplayPianoRoll(moment: moment, corrected: corrected)
                .frame(minHeight: 240)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))

            HStack(spacing: 10) {
                Button {
                    audio.play(moment: moment, corrected: corrected)
                } label: {
                    Label("Écouter", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button("Arrêter") { audio.stop() }
                    .buttonStyle(.bordered)
                    .disabled(!audio.isPlaying)

                if audio.isPlaying {
                    ProgressView().controlSize(.small)
                }

                Spacer()
                Text("Re-synthèse locale (sinusoïde + harmoniques) — aucun audio brut n'est conservé.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 440)
        .onDisappear { audio.stop() }
    }
}

/// Piano-roll minimal : notes attendues en barres, notes jouées décalées en
/// cents (et en rythme si l'on affiche la version jouée).
struct ReplayPianoRoll: View {
    let moment: ReplayMoment
    let corrected: Bool

    var body: some View {
        Canvas { context, size in
            let notes = moment.notes.sorted { $0.onset < $1.onset }
            guard !notes.isEmpty else { return }

            let minTime = notes.map(\.onset).min() ?? 0
            let maxTime = notes.map { $0.onset + $0.duration }.max() ?? 1
            let timeSpan = max(0.2, maxTime - minTime)
            let minMidi = (notes.map(\.midi).min() ?? 48) - 2
            let maxMidi = (notes.map(\.midi).max() ?? 60) + 2
            let midiSpan = max(4, maxMidi - minMidi)

            let left: CGFloat = 34
            let right: CGFloat = 12
            let top: CGFloat = 18
            let bottom: CGFloat = 22
            let width = max(1, size.width - left - right)
            let height = max(1, size.height - top - bottom)

            func x(_ time: Double) -> CGFloat {
                left + CGFloat((time - minTime) / timeSpan) * width
            }
            func y(_ midi: Double) -> CGFloat {
                top + CGFloat(1 - (midi - Double(minMidi)) / Double(midiSpan)) * height
            }

            // Grille horizontale (demi-tons) et verticale (temps).
            for midi in minMidi...maxMidi {
                let lineY = y(Double(midi))
                var path = Path()
                path.move(to: CGPoint(x: left, y: lineY))
                path.addLine(to: CGPoint(x: left + width, y: lineY))
                context.stroke(path, with: .color(.secondary.opacity(midi % 12 == 0 ? 0.22 : 0.08)), lineWidth: 0.5)
            }
            for step in 0...4 {
                let time = minTime + timeSpan * Double(step) / 4
                var path = Path()
                path.move(to: CGPoint(x: x(time), y: top))
                path.addLine(to: CGPoint(x: x(time), y: top + height))
                context.stroke(path, with: .color(.secondary.opacity(0.08)), lineWidth: 0.5)
            }

            for note in notes {
                let isTarget = note.scoreIndex == moment.scoreIndex
                let start = corrected ? note.onset : note.onset + note.rhythmMs / 1000
                let playedMidi = corrected ? Double(note.midi) : Double(note.midi) + note.cents / 100
                let rect = CGRect(
                    x: x(start),
                    y: y(playedMidi) - 5,
                    width: max(3, x(start + note.duration) - x(start)),
                    height: 10
                )
                let color: Color = isTarget ? .orange : (corrected ? .teal : .blue)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color.opacity(0.75)))

                // Trait de justesse : la note attendue reste visible en gris.
                if !corrected, abs(note.cents) >= 10 {
                    let expected = CGRect(
                        x: x(note.onset),
                        y: y(Double(note.midi)) - 1,
                        width: max(2, x(note.onset + note.duration) - x(note.onset)),
                        height: 2
                    )
                    context.fill(Path(roundedRect: expected, cornerRadius: 1), with: .color(.gray.opacity(0.55)))
                }

                if isTarget {
                    context.draw(
                        Text("m. \(note.measure)").font(.caption2).foregroundColor(.orange),
                        at: CGPoint(x: rect.maxX + 4, y: rect.midY),
                        anchor: .leading
                    )
                }
            }

            // Légende des hauteurs.
            for midi in stride(from: minMidi, through: maxMidi, by: 12) {
                context.draw(
                    Text(NoteNamer.name(forMidi: midi)).font(.caption2).foregroundColor(.secondary),
                    at: CGPoint(x: left - 4, y: y(Double(midi))),
                    anchor: .trailing
                )
            }
        }
    }
}
