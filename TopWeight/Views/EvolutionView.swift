import SwiftUI
import SwiftData
import Charts

struct EvolutionView: View {
    @Query(sort: \WorkoutRecord.date, order: .forward) private var records: [WorkoutRecord]
    @Query(sort: \User.createdAt, order: .reverse) private var users: [User]

    @State private var selectedUser: User?
    @State private var selectedExercise: Exercise?

    private var usersWithRecords: [User] {
        let userIds = Set(records.compactMap { $0.user?.id })
        return users.filter { userIds.contains($0.id) }
    }

    private var exercisesForSelectedUser: [Exercise] {
        guard let user = selectedUser else { return [] }
        let userRecords = records.filter { $0.user?.id == user.id }
        return Array(Set(userRecords.compactMap(\.exercise))).sorted { ($0.name) < ($1.name) }
    }

    private var chartRecords: [WorkoutRecord] {
        guard let user = selectedUser, let exercise = selectedExercise else { return [] }
        return records.filter {
            $0.user?.id == user.id && $0.exercise?.id == exercise.id
        }.sorted { $0.date < $1.date }
    }

    private var chartValue: (WorkoutRecord) -> Double {
        guard let exercise = selectedExercise else { return { _ in 0 } }
        if exercise.isDistanceType {
            return { ($0.distance ?? 0) }
        } else if exercise.isTimedType {
            return { Double(($0.seconds ?? 0) * $0.series) }
        } else if exercise.isRepsOnlyType {
            return { Double($0.reps * $0.series) }
        } else {
            return { $0.weight * Double($0.reps * $0.series) }
        }
    }

    private var yAxisLabel: String {
        guard let exercise = selectedExercise else { return "" }
        if exercise.isDistanceType { return "km" }
        if exercise.isTimedType { return "total seconds" }
        if exercise.isRepsOnlyType { return "total reps" }
        return "volume (kg)"
    }

    private var chartTitle: String {
        guard let user = selectedUser?.name, let exercise = selectedExercise?.name else {
            return "Select user and exercise"
        }
        return "\(user) – \(exercise)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if usersWithRecords.isEmpty {
                        emptyState
                    } else {
                        userSection
                        exerciseSection
                        if selectedUser != nil && selectedExercise != nil {
                            chartSection
                        } else {
                            Text("Select a user and an exercise to see the evolution.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Evolution")
            .onAppear {
                if selectedUser == nil, let first = usersWithRecords.first {
                    selectedUser = first
                }
                if selectedExercise == nil, let first = exercisesForSelectedUser.first {
                    selectedExercise = first
                }
            }
            .onChange(of: selectedUser) { _, _ in
                let exercises = exercisesForSelectedUser
                if exercises.isEmpty {
                    selectedExercise = nil
                } else if selectedExercise.map({ ex in !exercises.contains(where: { $0.id == ex.id }) }) ?? true {
                    selectedExercise = exercises.first
                }
            }
        }
    }

    private var userSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(usersWithRecords, id: \.id) { user in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedUser = user
                        } label: {
                            HStack(spacing: 8) {
                                UserAvatarView(user: user, size: 28)
                                Text(user.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedUser?.id == user.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 48)
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if exercisesForSelectedUser.isEmpty {
                Text("No exercises recorded for this user.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 44)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(exercisesForSelectedUser, id: \.id) { exercise in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedExercise = exercise
                            } label: {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedExercise?.id == exercise.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 48)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chartTitle)
                .font(.headline)
            if chartRecords.isEmpty {
                Text("No data yet for this exercise.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else {
                Chart(chartRecords) { record in
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value(yAxisLabel, chartValue(record))
                    )
                    .foregroundStyle(Color.accentColor)
                    PointMark(
                        x: .value("Date", record.date),
                        y: .value(yAxisLabel, chartValue(record))
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(24)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day().month(.abbreviated))
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No data yet",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Record workouts to see your evolution over time.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityLabel("No data yet. Record workouts to see your evolution.")
    }
}

#Preview {
    EvolutionView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self, PersonalBest.self], inMemory: true)
}
