import SwiftUI
import SwiftData

struct TopsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonalBest.topWeight, order: .reverse) private var personalBests: [PersonalBest]

    private var groupedByUser: [(User, [PersonalBest])] {
        let grouped = Dictionary(grouping: personalBests) { pb in
            pb.user?.id ?? UUID()
        }
        return grouped.compactMap { _, pbs in
            guard let user = pbs.first?.user else { return nil }
            let sorted = pbs.sorted { ($0.exercise?.name ?? "") < ($1.exercise?.name ?? "") }
            return (user, sorted)
        }
        .sorted { ($0.0.name) < ($1.0.name) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if personalBests.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedByUser, id: \.0.id) { user, pbs in
                            Section {
                                ForEach(pbs.filter { $0.exercise != nil }, id: \.exercise!.id) { pb in
                                    TopsRow(personalBest: pb, exercise: pb.exercise!)
                                }
                            } header: {
                                HStack {
                                    UserAvatarView(user: user, size: 28)
                                    Text(user.name)
                                        .font(.headline)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tops")
            .onAppear {
                PersonalBest.migrateFromExistingRecords(modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No personal bests yet",
            systemImage: "trophy.fill",
            description: Text("Record workouts to see your top weights, reps, and distances here.")
        )
        .accessibilityLabel("No personal bests yet. Record workouts to see your tops.")
    }
}

struct TopsRow: View {
    let personalBest: PersonalBest
    let exercise: Exercise

    private var detailText: String {
        if exercise.isDistanceType {
            if let dist = personalBest.topDistance {
                return String(format: "%.1f km", dist)
            }
            return "—"
        } else if exercise.isTimedType {
            let secs = personalBest.topSeconds ?? 0
            let totalSecs = secs * personalBest.topSeries
            return "\(secs)s × \(personalBest.topSeries) series = \(totalSecs)s total"
        } else if exercise.isRepsOnlyType {
            let totalReps = personalBest.topReps * personalBest.topSeries
            return "\(personalBest.topReps) reps × \(personalBest.topSeries) series = \(totalReps) total"
        } else {
            let volume = personalBest.topWeight * Double(personalBest.topReps * personalBest.topSeries)
            return "\(Int(personalBest.topWeight)) kg × \(personalBest.topReps) reps × \(personalBest.topSeries) series = \(Int(volume)) kg vol"
        }
    }

    private var dateText: String? {
        guard let date = personalBest.topDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(detailText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            if let dateText {
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(detailText)\(dateText.map { ", \($0)" } ?? "")")
    }
}

#Preview {
    TopsView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self, PersonalBest.self], inMemory: true)
}
