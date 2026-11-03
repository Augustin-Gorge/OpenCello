import SwiftUI
import Combine
import AppKit

struct ExercisesView: View {
    @EnvironmentObject private var engine: SessionEngine
    @State private var category = "Tous"
    @State private var selectedExercise: Exercise?

    private var recommended: [Exercise] {
        engine.recommendedExerciseIDs.compactMap(ExerciseCatalog.exercise)
    }

    private var filtered: [Exercise] {
        category == "Tous"
            ? ExerciseCatalog.all
            : ExerciseCatalog.all.filter { $0.category == category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercices").font(.title2.bold())
                Spacer()
                Text("\(ExerciseCatalog.all.count) fiches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: engine.requestedExerciseID) { _, id in
                if let id, let exercise = ExerciseCatalog.exercise(id: id) {
                    selectedExercise = exercise
                    engine.requestedExerciseID = nil
                }
            }

            if !recommended.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommandés pour vous").font(.caption.bold()).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recommended) { exercise in
                                Button {
                                    selectedExercise = exercise
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.title).font(.callout.weight(.semibold))
                                        Text("\(exercise.category) · \(exercise.durationMinutes) min")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(10)
                                    .frame(width: 190, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(nsColor: .controlBackgroundColor))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Picker("Catégorie", selection: $category) {
                ForEach(ExerciseCatalog.categories, id: \.self) { item in
                    Text(item).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 620)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filtered) { exercise in
                        exerciseRow(exercise)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .padding(16)
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
                .environmentObject(engine)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            selectedExercise = exercise
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: engine.progress.isCompleted(exercise.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(engine.progress.isCompleted(exercise.id) ? .green : .secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.title).font(.callout.weight(.semibold))
                    Text(exercise.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text("\(exercise.category) · \(exercise.level) · \(exercise.durationMinutes) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @EnvironmentObject private var engine: SessionEngine
    @Environment(\.dismiss) private var dismiss

    @State private var remaining: Int
    @State private var running = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(exercise: Exercise) {
        self.exercise = exercise
        _remaining = State(initialValue: exercise.durationMinutes * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.title).font(.title2.bold())
                Spacer()
                Button("Fermer") { dismiss() }
            }

            Text("\(exercise.category) · \(exercise.level) · \(exercise.durationMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(exercise.summary).font(.callout)

            Divider()

            Text("Consignes").font(.headline)
            ForEach(exercise.instructions, id: \.self) { instruction in
                Text("• \(instruction)").font(.callout)
            }

            Text("Critères de réussite").font(.headline)
            ForEach(exercise.criteria, id: \.self) { criterion in
                Text("• \(criterion)").font(.callout).foregroundStyle(.secondary)
            }

            Text("Source : \(exercise.source)").font(.caption2).foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Text(timeString(remaining))
                    .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                Button(running ? "Pause" : "Démarrer") { running.toggle() }
                    .buttonStyle(.borderedProminent)
                Button("Réinitialiser") {
                    running = false
                    remaining = exercise.durationMinutes * 60
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(engine.progress.isCompleted(exercise.id) ? "Marquer à revoir" : "Marquer comme fait") {
                    engine.progress.markExercise(
                        exercise.id,
                        completed: !engine.progress.isCompleted(exercise.id)
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 560)
        .onReceive(timer) { _ in
            guard running, remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 { running = false }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
