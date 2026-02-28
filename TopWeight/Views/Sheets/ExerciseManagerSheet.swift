import SwiftUI
import SwiftData

struct ExerciseManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]

    @State private var newExerciseName = ""
    @State private var exerciseToEdit: Exercise?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Exercise name", text: $newExerciseName)
                        Button("Add") {
                            addExercise()
                        }
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Add new exercise")
                }

                Section {
                    ForEach(exercises, id: \.id) { exercise in
                        Button {
                            exerciseToEdit = exercise
                        } label: {
                            Text(exercise.name)
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
        }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let exercise = Exercise(name: name)
        modelContext.insert(exercise)

        do {
            try modelContext.save()
            newExerciseName = ""
        } catch {
            // In a real app, show error
        }
    }
}

struct EditExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    let exercise: Exercise
    @State private var name: String
    let onDismiss: () -> Void

    init(exercise: Exercise, onDismiss: @escaping () -> Void) {
        self.exercise = exercise
        self._name = State(initialValue: exercise.name)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise name", text: $name)
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
