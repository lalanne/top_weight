import SwiftUI
import SwiftData

struct EditWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    let record: WorkoutRecord
    let onDismiss: () -> Void

    @State private var weight: Double
    @State private var reps: Int
    @State private var series: Int
    @State private var distance: Double
    @State private var isIndoor: Bool

    private var isDistanceEntry: Bool { record.exercise?.isDistanceType == true }
    private var isRepsOnlyEntry: Bool { record.exercise?.isRepsOnlyType == true }
    private let weightStep: Double = 0.5

    init(record: WorkoutRecord, onDismiss: @escaping () -> Void) {
        self.record = record
        self.onDismiss = onDismiss
        self._weight = State(initialValue: record.weight)
        self._reps = State(initialValue: max(1, record.reps))
        self._series = State(initialValue: record.exercise?.isRepsOnlyType == true && record.series == 0 ? 1 : max(1, record.series))
        self._distance = State(initialValue: record.distance ?? 0)
        self._isIndoor = State(initialValue: record.isIndoor ?? false)
    }

    private var canSave: Bool {
        if isDistanceEntry {
            return distance > 0
        } else if isRepsOnlyEntry {
            return reps > 0 && series > 0
        } else {
            return weight > 0 && reps > 0 && series > 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if let user = record.user {
                            UserAvatarView(user: user, size: 36)
                        }
                        Text(record.user?.name ?? "—")
                            .font(.headline)
                    }
                    Text(record.exercise?.name ?? "—")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Workout")
                }

                Section {
                    if isDistanceEntry {
                        TextField("Distance (km)", value: $distance, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                        StepperField(
                            title: "Distance (km)",
                            value: $distance,
                            step: 0.1,
                            range: 0...100,
                            format: "%.1f"
                        )
                        Picker("Location", selection: $isIndoor) {
                            Text("Outdoors").tag(false)
                            Text("Indoors").tag(true)
                        }
                    } else if isRepsOnlyEntry {
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
                    } else {
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
                } header: {
                    Text("Details")
                }
            }
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        onDismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveChanges() {
        if isDistanceEntry {
            record.distance = distance
            record.isIndoor = isIndoor
            record.weight = 0
            record.reps = 0
            record.series = 0
        } else if isRepsOnlyEntry {
            record.reps = reps
            record.series = series
            record.weight = 0
            record.distance = nil
            record.isIndoor = nil
        } else {
            record.weight = weight
            record.reps = reps
            record.series = series
            record.distance = nil
            record.isIndoor = nil
        }
        try? modelContext.save()
        if let user = record.user, let exercise = record.exercise {
            PersonalBest.recompute(modelContext: modelContext, user: user, exercise: exercise)
            try? modelContext.save()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

