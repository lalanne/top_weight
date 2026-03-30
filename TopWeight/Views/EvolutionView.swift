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
        return { exercise.chartMetricValue(for: $0) }
    }

    private var yAxisLabel: String {
        selectedExercise?.chartYAxisLabel ?? ""
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
            HStack {
                if let user = selectedUser {
                    UserAvatarView(user: user, size: 28)
                }
                Picker("Select user", selection: $selectedUser) {
                    Text("None").tag(nil as User?)
                    ForEach(usersWithRecords, id: \.id) { user in
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
                Picker("Select exercise", selection: $selectedExercise) {
                    Text("None").tag(nil as Exercise?)
                    ForEach(exercisesForSelectedUser, id: \.id) { exercise in
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
