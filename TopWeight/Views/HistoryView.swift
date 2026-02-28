import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var records: [WorkoutRecord]

    private var groupedRecords: [(String, [WorkoutRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped
            .map { (date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
            .map { (sectionTitle(for: $0.date), $0.records) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedRecords, id: \.0) { sectionTitle, sectionRecords in
                            Section(sectionTitle) {
                                ForEach(sectionRecords, id: \.id) { record in
                                    HistoryRow(record: record)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                modelContext.delete(record)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No workouts yet",
            systemImage: "dumbbell.fill",
            description: Text("Your recorded workouts will appear here. Switch to the Record tab to add your first workout.")
        )
        .accessibilityLabel("No workouts yet. Switch to Record tab to add your first workout.")
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct HistoryRow: View {
    let record: WorkoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let user = record.user {
                    UserAvatarView(user: user, size: 32)
                }
                Text(record.user?.name ?? "—")
                    .font(.headline)
                Spacer()
                Text(formatTime(record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(record.exercise?.name ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(detailText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.user?.name ?? "Unknown"), \(record.exercise?.name ?? "Unknown"), \(detailText)")
    }

    private var detailText: String {
        if record.isDistanceEntry, let dist = record.distance {
            let location = (record.isIndoor == true) ? "indoors" : "outdoors"
            return String(format: "%.1f km, %@", dist, location)
        } else if record.exercise?.isRepsOnlyType == true {
            return "\(record.reps) reps"
        } else {
            return "\(Int(record.weight)) kg × \(record.reps) reps × \(record.series) series"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}
