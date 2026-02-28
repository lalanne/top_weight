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
    @State private var distance: Double = 0
    @State private var isIndoor: Bool = false
    @State private var showUserSheet = false
    @State private var showExerciseSheet = false
    @State private var showSavedFeedback = false
    @State private var showSaveError = false

    private let lastUserIDKey = "lastSelectedUserID"
    private let lastExerciseIDKey = "lastSelectedExerciseID"
    private let weightStep: Double = 2.5

    private var isDistanceExercise: Bool {
        selectedExercise?.isDistanceType == true
    }

    private var isRepsOnlyExercise: Bool {
        selectedExercise?.isRepsOnlyType == true
    }

    private var canSave: Bool {
        guard selectedUser != nil, selectedExercise != nil else { return false }
        if isDistanceExercise {
            return distance > 0
        } else if isRepsOnlyExercise {
            return reps > 0
        } else {
            return weight > 0 && reps > 0 && series > 0
        }
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
            .alert("Could not save", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Something went wrong. Please try again.")
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

            if isDistanceExercise {
                distanceInputSection
            } else if isRepsOnlyExercise {
                repsOnlyInputSection
            } else {
                strengthInputSection
            }
        }
    }

    private var strengthInputSection: some View {
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

    private var distanceInputSection: some View {
        VStack(spacing: 20) {
            StepperField(
                title: "Distance (km)",
                value: $distance,
                step: 0.5,
                range: 0...100,
                format: "%.1f"
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                Picker("", selection: $isIndoor) {
                    Text("Outdoors").tag(false)
                    Text("Indoors").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var repsOnlyInputSection: some View {
        VStack(spacing: 20) {
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
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var saveButton: some View {
        Button(action: saveRecord) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(isDistanceExercise || isRepsOnlyExercise ? "Save" : "Save workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSave)
        .accessibilityHint("Saves the workout with selected user, exercise, weight, reps, and series")
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
        .transition(.scale.combined(with: .opacity))
    }

    private func sectionHeader(_ title: String, addAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                addAction()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Add \(title)")
        }
    }

    private func selectUser(_ user: User) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedUser = user
        UserDefaults.standard.set(user.id.uuidString, forKey: lastUserIDKey)
    }

    private func selectExercise(_ exercise: Exercise) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedExercise = exercise
        UserDefaults.standard.set(exercise.id.uuidString, forKey: lastExerciseIDKey)
        if exercise.isDistanceType {
            distance = 0
            isIndoor = false
        } else if exercise.isRepsOnlyType {
            reps = 1
        } else {
            weight = 0
            reps = 10
            series = 1
        }
    }

    private func restoreLastUsed() {
        if let idStr = UserDefaults.standard.string(forKey: lastUserIDKey),
           let id = UUID(uuidString: idStr) {
            selectedUser = users.first { $0.id == id }
        }
        if let idStr = UserDefaults.standard.string(forKey: lastExerciseIDKey),
           let id = UUID(uuidString: idStr),
           let exercise = exercises.first(where: { $0.id == id }) {
            selectedExercise = exercise
            if exercise.isDistanceType {
                distance = 0
                isIndoor = false
            } else if exercise.isRepsOnlyType {
                reps = 1
            } else {
                weight = 0
                reps = 10
                series = 1
            }
        }
    }

    private func saveRecord() {
        guard let user = selectedUser, let exercise = selectedExercise else { return }

        let record: WorkoutRecord
        if isDistanceExercise {
            guard distance > 0 else { return }
            record = WorkoutRecord(
                weight: 0, reps: 0, series: 0,
                distance: distance, isIndoor: isIndoor,
                user: user, exercise: exercise
            )
        } else if isRepsOnlyExercise {
            guard reps > 0 else { return }
            record = WorkoutRecord(
                weight: 0, reps: reps, series: 0,
                user: user, exercise: exercise
            )
        } else {
            guard weight > 0, reps > 0, series > 0 else { return }
            record = WorkoutRecord(
                weight: weight, reps: reps, series: series,
                user: user, exercise: exercise
            )
        }
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
            showSaveError = true
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
        .accessibilityLabel(user.name)
        .accessibilityHint(isSelected ? "Selected" : "Select this user")
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
        .accessibilityLabel(exercise.name)
        .accessibilityHint(isSelected ? "Selected" : "Select this exercise")
    }
}

struct AddChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
        .accessibilityHint("Opens form to add new")
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Decrease \(title)")
                Text(String(format: format, value))
                    .font(.title)
                    .fontWeight(.semibold)
                    .frame(minWidth: 60, alignment: .center)
                    .accessibilityLabel("\(title): \(String(format: format, value))")
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Increase \(title)")
            }
        }
    }
}

#Preview {
    RecordView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}
