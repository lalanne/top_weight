import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt, order: .reverse) private var users: [User]
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]

    @State private var selectedUser: User?
    @State private var selectedExercise: Exercise?
    @State private var weight: Double = 0
    @State private var reps: Int = 10
    @State private var series: Int = 1
    @State private var showUserSheet = false
    @State private var showExerciseSheet = false
    @State private var showSavedFeedback = false

    private let lastUserIDKey = "lastSelectedUserID"
    private let lastExerciseIDKey = "lastSelectedExerciseID"
    private let weightStep: Double = 2.5

    private var canSave: Bool {
        selectedUser != nil &&
        selectedExercise != nil &&
        weight > 0 &&
        reps > 0 &&
        series > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    userSection
                    exerciseSection
                    inputSection
                    saveButton
                }
                .padding()
            }
            .navigationTitle("Record")
            .overlay {
                if showSavedFeedback {
                    savedFeedbackOverlay
                }
            }
            .sheet(isPresented: $showUserSheet) {
                UserManagerSheet()
            }
            .sheet(isPresented: $showExerciseSheet) {
                ExerciseManagerSheet()
            }
            .onAppear(perform: restoreLastUsed)
        }
    }

    private var userSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("User", addAction: { showUserSheet = true })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(users, id: \.id) { user in
                        UserChip(
                            user: user,
                            isSelected: selectedUser?.id == user.id,
                            action: { selectUser(user) }
                        )
                    }
                    AddChip(title: "Add user", action: { showUserSheet = true })
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 48)
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Exercise", addAction: { showExerciseSheet = true })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(exercises, id: \.id) { exercise in
                        ExerciseChip(
                            exercise: exercise,
                            isSelected: selectedExercise?.id == exercise.id,
                            action: { selectExercise(exercise) }
                        )
                    }
                    AddChip(title: "Add exercise", action: { showExerciseSheet = true })
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 48)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 20) {
                StepperField(
                    title: "Weight (kg)",
                    value: $weight,
                    step: weightStep,
                    range: 0...500,
                    format: "%.1f"
                )
                StepperField(
                    title: "Repetitions",
                    value: Binding(
                        get: { Double(reps) },
                        set: { reps = max(1, Int($0)) }
                    ),
                    step: 1,
                    range: 1...999,
                    format: "%.0f"
                )
                StepperField(
                    title: "Series",
                    value: Binding(
                        get: { Double(series) },
                        set: { series = max(1, min(50, Int($0))) }
                    ),
                    step: 1,
                    range: 1...50,
                    format: "%.0f"
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var saveButton: some View {
        Button(action: saveRecord) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Save workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSave)
    }

    private var savedFeedbackOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("Saved!")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
    }

    private func sectionHeader(_ title: String, addAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button(action: addAction) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
        }
    }

    private func selectUser(_ user: User) {
        selectedUser = user
        UserDefaults.standard.set(user.id.uuidString, forKey: lastUserIDKey)
    }

    private func selectExercise(_ exercise: Exercise) {
        selectedExercise = exercise
        UserDefaults.standard.set(exercise.id.uuidString, forKey: lastExerciseIDKey)
    }

    private func restoreLastUsed() {
        if let idStr = UserDefaults.standard.string(forKey: lastUserIDKey),
           let id = UUID(uuidString: idStr) {
            selectedUser = users.first { $0.id == id }
        }
        if let idStr = UserDefaults.standard.string(forKey: lastExerciseIDKey),
           let id = UUID(uuidString: idStr) {
            selectedExercise = exercises.first { $0.id == id }
        }
    }

    private func saveRecord() {
        guard let user = selectedUser, let exercise = selectedExercise else { return }
        guard weight > 0, reps > 0, series > 0 else { return }

        let record = WorkoutRecord(
            weight: weight,
            reps: reps,
            series: series,
            user: user,
            exercise: exercise
        )
        modelContext.insert(record)

        do {
            try modelContext.save()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation {
                showSavedFeedback = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    showSavedFeedback = false
                }
            }
        } catch {
            // In a real app, show an error alert
        }
    }
}

// MARK: - Supporting Views

struct UserChip: View {
    let user: User
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(user.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? .accentColor : .gray.opacity(0.5))
    }
}

struct ExerciseChip: View {
    let exercise: Exercise
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(exercise.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? .accentColor : .gray.opacity(0.5))
    }
}

struct AddChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }
}

struct StepperField: View {
    let title: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .disabled(value <= range.lowerBound)
                Text(String(format: format, value))
                    .font(.title)
                    .fontWeight(.semibold)
                    .frame(minWidth: 60, alignment: .center)
                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(value >= range.upperBound)
            }
        }
    }
}

#Preview {
    RecordView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}
