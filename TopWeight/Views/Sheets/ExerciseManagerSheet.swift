import SwiftUI
import SwiftData

struct ExerciseManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]

    @State private var newExerciseName = ""
    @State private var newExerciseType: ExerciseType = .strength
    @State private var exerciseToEdit: Exercise?
    @State private var showAddError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Exercise name", text: $newExerciseName)
                    Picker("Type", selection: $newExerciseType) {
                        Text("Strength").tag(ExerciseType.strength)
                        Text("Distance").tag(ExerciseType.distance)
                        Text("Reps only").tag(ExerciseType.repsOnly)
                    }
                    .pickerStyle(.menu)
                    Button("Add") {
                        addExercise()
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Add new exercise")
                } footer: {
                    Text("Strength: weight, reps, series. Distance: km + indoor/outdoor. Reps only: just repetitions (e.g. Push-ups, Pull-ups).")
                }

                Section {
                    ForEach(exercises, id: \.id) { exercise in
                        Button {
                            exerciseToEdit = exercise
                        } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                Text(typeLabel(for: exercise))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(exercise)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                exerciseToEdit = exercise
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                } header: {
                    Text("Exercises")
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $exerciseToEdit) { exercise in
                EditExerciseSheet(exercise: exercise) {
                    exerciseToEdit = nil
                }
            }
            .alert("Could not add exercise", isPresented: $showAddError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Something went wrong. Please try again.")
            }
        }
    }

    private func typeLabel(for exercise: Exercise) -> String {
        switch exercise.exerciseType {
        case .strength: return "Strength"
        case .distance: return "Distance"
        case .repsOnly: return "Reps only"
        }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let exercise = Exercise(name: name, exerciseType: newExerciseType)
        modelContext.insert(exercise)

        do {
            try modelContext.save()
            newExerciseName = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            showAddError = true
        }
    }
}

struct EditExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    let exercise: Exercise
    @State private var name: String
    @State private var exerciseType: ExerciseType
    let onDismiss: () -> Void

    init(exercise: Exercise, onDismiss: @escaping () -> Void) {
        self.exercise = exercise
        self._name = State(initialValue: exercise.name)
        self._exerciseType = State(initialValue: exercise.exerciseType)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise name", text: $name)
                Picker("Type", selection: $exerciseType) {
                    Text("Strength").tag(ExerciseType.strength)
                    Text("Distance").tag(ExerciseType.distance)
                    Text("Reps only").tag(ExerciseType.repsOnly)
                }
                .pickerStyle(.menu)
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        exercise.name = trimmed
                        exercise.exerciseType = exerciseType
                        try? modelContext.save()
                        onDismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

extension Exercise: Identifiable {}

#Preview {
    ExerciseManagerSheet()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}
