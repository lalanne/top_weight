import SwiftUI
import SwiftData
import Charts

struct CompareEvolutionView: View {
    @Query(sort: \WorkoutRecord.date, order: .forward) private var records: [WorkoutRecord]
    @Query(sort: \User.createdAt, order: .reverse) private var users: [User]

    @State private var selectedExercise: Exercise?
    @State private var selectedUserIDs: Set<UUID> = []

    private var exercisesWithData: [Exercise] {
        let set = Set(records.compactMap(\.exercise))
        return Array(set).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var usersForExercise: [User] {
        guard let exercise = selectedExercise else { return [] }
        let ids = Set(records.filter { $0.exercise?.id == exercise.id }.compactMap { $0.user?.id })
        return users.filter { ids.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var userSeries: [UserSeries] {
        guard let exercise = selectedExercise else { return [] }
        return selectedUserIDs.compactMap { userId -> UserSeries? in
            guard let user = users.first(where: { $0.id == userId }) else { return nil }
            let userRecords = records.filter { $0.user?.id == userId && $0.exercise?.id == exercise.id }
                .sorted { $0.date < $1.date }
            guard !userRecords.isEmpty else { return nil }
            return UserSeries(userId: user.id, userName: user.name, records: userRecords)
        }
        .sorted { $0.userName.localizedCaseInsensitiveCompare($1.userName) == .orderedAscending }
    }

    private var yAxisLabel: String {
        selectedExercise?.chartYAxisLabel ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if exercisesWithData.isEmpty {
                        emptyState
                    } else {
                        exerciseSection
                        usersSection
                        if selectedExercise != nil {
                            chartSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Compare")
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercisesWithData.first
                }
                syncSelectionToExercise()
            }
            .onChange(of: selectedExercise?.id) { _, _ in
                syncSelectionToExercise()
            }
        }
    }

    private func syncSelectionToExercise() {
        guard let exercise = selectedExercise else {
            selectedUserIDs = []
            return
        }
        let ids = Set(records.filter { $0.exercise?.id == exercise.id }.compactMap { $0.user?.id })
        let valid = selectedUserIDs.intersection(ids)
        if valid.isEmpty {
            selectedUserIDs = ids
        } else {
            selectedUserIDs = valid
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Picker("Exercise", selection: $selectedExercise) {
                ForEach(exercisesWithData, id: \.id) { exercise in
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

    private var usersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Users on chart")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                if usersForExercise.count >= 2 {
                    Button("All") {
                        selectedUserIDs = Set(usersForExercise.map(\.id))
                    }
                    .font(.caption)
                    Button("None") {
                        selectedUserIDs = []
                    }
                    .font(.caption)
                }
            }
            if usersForExercise.isEmpty {
                Text("No users have logged this exercise yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(usersForExercise, id: \.id) { user in
                        Toggle(isOn: Binding(
                            get: { selectedUserIDs.contains(user.id) },
                            set: { on in
                                if on {
                                    selectedUserIDs.insert(user.id)
                                } else {
                                    selectedUserIDs.remove(user.id)
                                }
                            }
                        )) {
                            HStack(spacing: 10) {
                                UserAvatarView(user: user, size: 28)
                                Text(user.name)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let exercise = selectedExercise {
                Text(exercise.name)
                    .font(.headline)
            }
            if selectedUserIDs.isEmpty {
                Text("Select at least one user to compare.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else if userSeries.isEmpty {
                Text("No data for the selected users.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else if let exercise = selectedExercise {
                Chart {
                    ForEach(userSeries) { series in
                        ForEach(series.records) { record in
                            LineMark(
                                x: .value("Date", record.date),
                                y: .value(yAxisLabel, exercise.chartMetricValue(for: record))
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(by: .value("User", series.userName))
                            .symbol(.circle)
                            .symbolSize(36)
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 16)
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
                .frame(height: 260)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing to compare",
            systemImage: "person.3",
            description: Text("Record the same exercise for several users to see their progress on one chart.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityLabel("Nothing to compare. Record workouts for multiple users first.")
    }
}

private struct UserSeries: Identifiable {
    var id: UUID { userId }
    let userId: UUID
    let userName: String
    let records: [WorkoutRecord]
}

#Preview {
    CompareEvolutionView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self, PersonalBest.self], inMemory: true)
}
