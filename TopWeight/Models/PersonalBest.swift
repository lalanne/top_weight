import Foundation
import SwiftData

/// Stores the top weight, reps, series, and distance per user and exercise.
/// Recomputed from WorkoutRecords on every save, edit, or delete.
@Model
final class PersonalBest {
    static func recompute(modelContext: ModelContext, user: User, exercise: Exercise) {
        let userId = user.id
        let exerciseId = exercise.id
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate<WorkoutRecord> { record in
                record.user?.id == userId && record.exercise?.id == exerciseId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let records: [WorkoutRecord]
        do {
            records = try modelContext.fetch(descriptor)
        } catch {
            return
        }

        guard !records.isEmpty else {
            // Delete PersonalBest if no records remain
            let pbDescriptor = FetchDescriptor<PersonalBest>(
                predicate: #Predicate<PersonalBest> { pb in
                    pb.user?.id == userId && pb.exercise?.id == exerciseId
                }
            )
            if let existing = try? modelContext.fetch(pbDescriptor).first {
                modelContext.delete(existing)
            }
            try? modelContext.save()
            return
        }

        if exercise.isDistanceType {
            let topDistance = records.compactMap(\.distance).max() ?? 0
            upsert(modelContext: modelContext, user: user, exercise: exercise) { pb in
                pb.topWeight = 0
                pb.topReps = 0
                pb.topSeries = 0
                pb.topDistance = topDistance
            }
        } else if exercise.isRepsOnlyType {
            let topReps = records.map(\.reps).max() ?? 0
            let topSeries = records.map(\.series).max() ?? 0
            upsert(modelContext: modelContext, user: user, exercise: exercise) { pb in
                pb.topWeight = 0
                pb.topReps = topReps
                pb.topSeries = topSeries
                pb.topDistance = nil
            }
        } else {
            let topWeight = records.map(\.weight).max() ?? 0
            let topReps = records.map(\.reps).max() ?? 0
            let topSeries = records.map(\.series).max() ?? 0
            upsert(modelContext: modelContext, user: user, exercise: exercise) { pb in
                pb.topWeight = topWeight
                pb.topReps = topReps
                pb.topSeries = topSeries
                pb.topDistance = nil
            }
        }
        try? modelContext.save()
    }

    /// One-time migration: populate PersonalBests from existing WorkoutRecords.
    static func migrateFromExistingRecords(modelContext: ModelContext) {
        let recordsDescriptor = FetchDescriptor<WorkoutRecord>()
        let pbDescriptor = FetchDescriptor<PersonalBest>()
        guard
            let records = try? modelContext.fetch(recordsDescriptor),
            let existingCount = try? modelContext.fetchCount(pbDescriptor),
            !records.isEmpty,
            existingCount == 0
        else { return }

        var seen = Set<String>()
        for record in records {
            guard let user = record.user, let exercise = record.exercise else { continue }
            let key = "\(user.id.uuidString)-\(exercise.id.uuidString)"
            if seen.contains(key) { continue }
            seen.insert(key)
            recompute(modelContext: modelContext, user: user, exercise: exercise)
        }
        try? modelContext.save()
    }

    private static func upsert(
        modelContext: ModelContext,
        user: User,
        exercise: Exercise,
        update: (PersonalBest) -> Void
    ) {
        let userId = user.id
        let exerciseId = exercise.id
        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate<PersonalBest> { pb in
                pb.user?.id == userId && pb.exercise?.id == exerciseId
            }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            update(existing)
        } else {
            let pb = PersonalBest(user: user, exercise: exercise)
            modelContext.insert(pb)
            update(pb)
        }
    }

    var user: User?
    var exercise: Exercise?

    var topWeight: Double = 0
    var topReps: Int = 0
    var topSeries: Int = 0
    /// For distance exercises: top distance in km.
    var topDistance: Double?

    init(
        user: User? = nil,
        exercise: Exercise? = nil,
        topWeight: Double = 0,
        topReps: Int = 0,
        topSeries: Int = 0,
        topDistance: Double? = nil
    ) {
        self.user = user
        self.exercise = exercise
        self.topWeight = topWeight
        self.topReps = topReps
        self.topSeries = topSeries
        self.topDistance = topDistance
    }
}
