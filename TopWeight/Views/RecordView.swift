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
    @State private var seconds: Int = 0
    @State private var showUserSheet = false
    @State private var showExerciseSheet = false
    @State private var userToEdit: User?
    @State private var showSavedFeedback = false
    @State private var showSaveError = false
    @State private var workoutDate = Date()

    private let lastUserIDKey = "lastSelectedUserID"
    private let lastExerciseIDKey = "lastSelectedExerciseID"
    private let weightStep: Double = 0.5

    private var isDistanceExercise: Bool {
        selectedExercise?.isDistanceType == true
    }

    private var isRepsOnlyExercise: Bool {
        selectedExercise?.isRepsOnlyType == true
    }

    private var isTimedExercise: Bool {
        selectedExercise?.isTimedType == true
    }

    private var canSave: Bool {
        guard selectedUser != nil, selectedExercise != nil else { return false }
        if isDistanceExercise {
            return distance > 0
        } else if isTimedExercise {
            return seconds > 0 && series > 0
        } else if isRepsOnlyExercise {
            return reps > 0 && series > 0
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
                    dateSection
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
            .sheet(item: $userToEdit) { user in
                EditUserSheet(user: user) {
                    userToEdit = nil
                }
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
            HStack {
                if let user = selectedUser {
                    UserAvatarView(user: user, size: 28)
                }
                Picker("Select user", selection: Binding(
                    get: { selectedUser },
                    set: { newUser in
                        if let user = newUser { selectUser(user) }
                    }
                )) {
                    Text("None").tag(nil as User?)
                    ForEach(users, id: \.id) { user in
                        Text(user.name).tag(user as User?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Exercise", addAction: { showExerciseSheet = true })
            Picker("Select exercise", selection: Binding(
                get: { selectedExercise },
                set: { newExercise in
                    if let exercise = newExercise { selectExercise(exercise) }
                }
            )) {
                Text("None").tag(nil as Exercise?)
                ForEach(exercises, id: \.id) { exercise in
                    Text(exercise.name).tag(exercise as Exercise?)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date & time")
                .font(.title2)
                .fontWeight(.semibold)
            DatePicker(
                "When",
                selection: $workoutDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout date and time")
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.title2)
                .fontWeight(.semibold)

            if isDistanceExercise {
                distanceInputSection
            } else if isTimedExercise {
                timedInputSection
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
                step: 0.1,
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

    private var timedInputSection: some View {
        VStack(spacing: 20) {
            StepperField(
                title: "Seconds",
                value: Binding(
                    get: { Double(seconds) },
                    set: { seconds = max(0, Int($0)) }
                ),
                step: 1,
                range: 0...3600,
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

    private var saveButton: some View {
        Button(action: saveRecord) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(isDistanceExercise || isRepsOnlyExercise || isTimedExercise ? "Save" : "Save workout")
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
        } else if exercise.isTimedType {
            seconds = 0
            series = 1
        } else if exercise.isRepsOnlyType {
            reps = 1
            series = 1
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
            } else if exercise.isTimedType {
                seconds = 0
                series = 1
            } else if exercise.isRepsOnlyType {
                reps = 1
                series = 1
            } else {
                weight = 0
                reps = 10
                series = 1
            }
        }
    }

    private func saveRecord() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard let user = selectedUser, let exercise = selectedExercise else { return }

        let record: WorkoutRecord
        if isDistanceExercise {
            guard distance > 0 else { return }
            record = WorkoutRecord(
                weight: 0, reps: 0, series: 0,
                date: workoutDate,
                distance: distance, isIndoor: isIndoor,
                user: user, exercise: exercise
            )
        } else if isTimedExercise {
            guard seconds > 0, series > 0 else { return }
            record = WorkoutRecord(
                weight: 0, reps: 0, series: series,
                date: workoutDate,
                seconds: seconds,
                user: user, exercise: exercise
            )
        } else if isRepsOnlyExercise {
            guard reps > 0, series > 0 else { return }
            record = WorkoutRecord(
                weight: 0, reps: reps, series: series,
                date: workoutDate,
                user: user, exercise: exercise
            )
        } else {
            guard weight > 0, reps > 0, series > 0 else { return }
            record = WorkoutRecord(
                weight: weight, reps: reps, series: series,
                date: workoutDate,
                user: user, exercise: exercise
            )
        }
        modelContext.insert(record)

        do {
            try modelContext.save()
            PersonalBest.recompute(modelContext: modelContext, user: user, exercise: exercise)
            try? modelContext.save()
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
            workoutDate = Date()
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
            HStack(spacing: 8) {
                UserAvatarView(user: user, size: 28)
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? Color.accentColor : Color.gray.opacity(0.5))
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
        .tint(isSelected ? Color.accentColor : Color.gray.opacity(0.5))
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

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Decrease \(title)")

                if isEditing {
                    TextField("", text: $editText)
                        .font(.title)
                        .fontWeight(.semibold)
                        .frame(minWidth: 60, alignment: .center)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .onSubmit { commitEdit() }
                        .onChange(of: editText) { _, newText in
                            let normalized = newText.replacingOccurrences(of: ",", with: ".")
                            if let parsed = Double(normalized) {
                                value = min(range.upperBound, max(range.lowerBound, parsed))
                            }
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { commitEdit() }
                        }
                        .onAppear { isFocused = true }
                } else {
                    Text(String(format: format, value))
                        .font(.title)
                        .fontWeight(.semibold)
                        .frame(minWidth: 60, alignment: .center)
                        .accessibilityLabel("\(title): \(String(format: format, value))")
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editText = String(format: format, value)
                            isEditing = true
                        }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Increase \(title)")
            }
        }
    }

    private func commitEdit() {
        let normalized = editText.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized) {
            value = min(range.upperBound, max(range.lowerBound, parsed))
        }
        isEditing = false
    }
}

#Preview {
    RecordView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}
