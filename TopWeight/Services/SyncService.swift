import Foundation
import SwiftData
import Supabase

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
}

private struct PersonalBestKey: Hashable {
    let userId: UUID
    let exerciseId: UUID
}

/// Outbox-based push + last-write-wins pull/merge against the 3 Supabase tables.
/// Every existing local save/delete call site enqueues here; this service never
/// blocks a save on network — it only drains what it can, when it can.
@MainActor
@Observable
final class SyncService {
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncedAt: Date?

    private let client: SupabaseClient
    private let modelContext: ModelContext

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let payloadEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let payloadDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(client: SupabaseClient, modelContext: ModelContext) {
        self.client = client
        self.modelContext = modelContext
        if let ownerId = client.auth.currentSession?.user.id {
            lastSyncedAt = Self.loadLastSyncedAt(ownerId: ownerId)
        }
    }

    // MARK: - Enqueue (called from view mutation sites, regardless of sign-in state)

    /// Call after the local object is saved. Snapshots its current field values.
    func enqueueUpsert(_ table: SyncTable, id: UUID) {
        guard let payload = snapshotPayload(table: table, id: id, deletedAt: nil) else { return }
        storeOutboxEntry(table: table, recordID: id, opType: .upsert, payload: payload)
        Task { await drainOutbox() }
    }

    /// Call BEFORE deleting the local object, so its field values can still be
    /// captured for the remote tombstone (a deleted row can't be re-fetched).
    func enqueueDelete(_ table: SyncTable, id: UUID) {
        guard let payload = snapshotPayload(table: table, id: id, deletedAt: Date()) else { return }
        storeOutboxEntry(table: table, recordID: id, opType: .delete, payload: payload)
        Task { await drainOutbox() }
    }

    private func storeOutboxEntry(table: SyncTable, recordID: UUID, opType: SyncOpType, payload: Data) {
        let tableRaw = table.rawValue
        let descriptor = FetchDescriptor<SyncOutboxEntry>(
            predicate: #Predicate { $0.tableRawValue == tableRaw && $0.recordID == recordID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.opTypeRawValue = opType.rawValue
            existing.payload = payload
            existing.enqueuedAt = Date()
        } else {
            modelContext.insert(SyncOutboxEntry(table: table, recordID: recordID, opType: opType, payload: payload))
        }
        try? modelContext.save()
    }

    private func snapshotPayload(table: SyncTable, id: UUID, deletedAt: Date?) -> Data? {
        switch table {
        case .profile:
            guard let user = fetchUser(id: id) else { return nil }
            let row = ProfileRow(
                id: user.id, name: user.name, avatarSymbol: user.avatarSymbol,
                createdAt: user.createdAt, updatedAt: user.updatedAt, deletedAt: deletedAt
            )
            return try? Self.payloadEncoder.encode(row)
        case .exercise:
            guard let exercise = fetchExercise(id: id) else { return nil }
            let row = ExerciseRow(
                id: exercise.id, name: exercise.name, exerciseType: exercise.exerciseTypeRawValue,
                createdAt: exercise.createdAt, updatedAt: exercise.updatedAt, deletedAt: deletedAt
            )
            return try? Self.payloadEncoder.encode(row)
        case .workoutRecord:
            guard let record = fetchWorkoutRecord(id: id),
                  let userId = record.user?.id, let exerciseId = record.exercise?.id else { return nil }
            let row = WorkoutRecordRow(
                id: record.id, userId: userId, exerciseId: exerciseId,
                weight: record.weight, reps: record.reps, series: record.series, date: record.date,
                distance: record.distance, isIndoor: record.isIndoor, seconds: record.seconds,
                updatedAt: record.updatedAt, deletedAt: deletedAt
            )
            return try? Self.payloadEncoder.encode(row)
        }
    }

    // MARK: - Push

    func drainOutbox() async {
        guard client.auth.currentSession != nil else { return }
        let descriptor = FetchDescriptor<SyncOutboxEntry>(sortBy: [SortDescriptor(\.enqueuedAt)])
        guard let entries = try? modelContext.fetch(descriptor), !entries.isEmpty else { return }

        syncStatus = .syncing
        var encounteredError: Error?
        for table in [SyncTable.profile, .exercise, .workoutRecord] {
            for entry in entries where entry.table == table {
                do {
                    try await push(entry: entry)
                    modelContext.delete(entry)
                } catch {
                    encounteredError = error
                }
            }
        }
        try? modelContext.save()

        if let error = encounteredError {
            syncStatus = .error(error.localizedDescription)
        } else {
            syncStatus = .idle
            touchLastSyncedAt()
        }
    }

    private func push(entry: SyncOutboxEntry) async throws {
        switch entry.table {
        case .profile:
            let row = try Self.payloadDecoder.decode(ProfileRow.self, from: entry.payload)
            let params = ProfileUpsertParams(
                p_id: row.id, p_name: row.name, p_avatar_symbol: row.avatarSymbol,
                p_created_at: row.createdAt, p_updated_at: row.updatedAt, p_deleted_at: row.deletedAt
            )
            try await client.rpc("upsert_profile", params: params).execute()
        case .exercise:
            let row = try Self.payloadDecoder.decode(ExerciseRow.self, from: entry.payload)
            let params = ExerciseUpsertParams(
                p_id: row.id, p_name: row.name, p_exercise_type: row.exerciseType,
                p_created_at: row.createdAt, p_updated_at: row.updatedAt, p_deleted_at: row.deletedAt
            )
            try await client.rpc("upsert_exercise", params: params).execute()
        case .workoutRecord:
            let row = try Self.payloadDecoder.decode(WorkoutRecordRow.self, from: entry.payload)
            let params = WorkoutRecordUpsertParams(
                p_id: row.id, p_user_id: row.userId, p_exercise_id: row.exerciseId,
                p_weight: row.weight, p_reps: row.reps, p_series: row.series, p_date: row.date,
                p_distance: row.distance, p_is_indoor: row.isIndoor, p_seconds: row.seconds,
                p_updated_at: row.updatedAt, p_deleted_at: row.deletedAt
            )
            try await client.rpc("upsert_workout_record", params: params).execute()
        }
    }

    // MARK: - Pull + merge

    /// Fetches rows changed since the last sync and merges them into local SwiftData.
    /// Existing managed objects are mutated in place (never delete-and-reinsert) so
    /// held `@State` references (`recordToEdit`, `userToEdit`, etc.) stay valid.
    func pullAndMerge() async {
        guard let ownerId = client.auth.currentSession?.user.id else { return }
        syncStatus = .syncing
        let hadNoRecordsLocally = ((try? modelContext.fetchCount(FetchDescriptor<WorkoutRecord>())) ?? 0) == 0

        do {
            try await mergeProfiles()
            try await mergeExercises()
            var touchedPairs = Set<PersonalBestKey>()
            try await mergeWorkoutRecords(touchedPairs: &touchedPairs)
            try? modelContext.save()

            if hadNoRecordsLocally {
                PersonalBest.migrateFromExistingRecords(modelContext: modelContext)
            } else {
                for pair in touchedPairs {
                    if let user = fetchUser(id: pair.userId), let exercise = fetchExercise(id: pair.exerciseId) {
                        PersonalBest.recompute(modelContext: modelContext, user: user, exercise: exercise)
                    }
                }
            }
            try? modelContext.save()
            syncStatus = .idle
            touchLastSyncedAt(ownerId: ownerId)
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func mergeProfiles() async throws {
        let rows: [ProfileRow] = try await fetchRows(table: "profiles")
        for row in rows {
            if row.deletedAt != nil {
                if let local = fetchUser(id: row.id) {
                    modelContext.delete(local)
                }
                continue
            }
            if let local = fetchUser(id: row.id) {
                if row.updatedAt > local.updatedAt {
                    local.name = row.name
                    local.avatarSymbol = row.avatarSymbol
                    local.updatedAt = row.updatedAt
                }
            } else {
                let user = User(
                    id: row.id, name: row.name, createdAt: row.createdAt,
                    updatedAt: row.updatedAt, avatarSymbol: row.avatarSymbol
                )
                modelContext.insert(user)
            }
        }
    }

    private func mergeExercises() async throws {
        let rows: [ExerciseRow] = try await fetchRows(table: "exercises")
        for row in rows {
            if row.deletedAt != nil {
                if let local = fetchExercise(id: row.id) {
                    modelContext.delete(local)
                }
                continue
            }
            if let local = fetchExercise(id: row.id) {
                if row.updatedAt > local.updatedAt {
                    local.name = row.name
                    local.exerciseTypeRawValue = row.exerciseType
                    local.updatedAt = row.updatedAt
                }
            } else {
                let exercise = Exercise(
                    id: row.id, name: row.name,
                    exerciseType: ExerciseType(rawValue: row.exerciseType) ?? .strength,
                    createdAt: row.createdAt, updatedAt: row.updatedAt
                )
                modelContext.insert(exercise)
            }
        }
    }

    private func mergeWorkoutRecords(touchedPairs: inout Set<PersonalBestKey>) async throws {
        let rows: [WorkoutRecordRow] = try await fetchRows(table: "workout_records")
        for row in rows {
            if row.deletedAt != nil {
                if let local = fetchWorkoutRecord(id: row.id) {
                    if let uid = local.user?.id, let eid = local.exercise?.id {
                        touchedPairs.insert(PersonalBestKey(userId: uid, exerciseId: eid))
                    }
                    modelContext.delete(local)
                }
                continue
            }
            guard let user = fetchUser(id: row.userId), let exercise = fetchExercise(id: row.exerciseId) else { continue }
            if let local = fetchWorkoutRecord(id: row.id) {
                if row.updatedAt > local.updatedAt {
                    local.weight = row.weight
                    local.reps = row.reps
                    local.series = row.series
                    local.date = row.date
                    local.distance = row.distance
                    local.isIndoor = row.isIndoor
                    local.seconds = row.seconds
                    local.updatedAt = row.updatedAt
                    local.user = user
                    local.exercise = exercise
                }
            } else {
                let record = WorkoutRecord(
                    id: row.id, weight: row.weight, reps: row.reps, series: row.series, date: row.date,
                    updatedAt: row.updatedAt, distance: row.distance, isIndoor: row.isIndoor, seconds: row.seconds,
                    user: user, exercise: exercise
                )
                modelContext.insert(record)
            }
            touchedPairs.insert(PersonalBestKey(userId: user.id, exerciseId: exercise.id))
        }
    }

    private func fetchRows<T: Decodable>(table: String) async throws -> [T] {
        if let since = lastSyncedAt {
            return try await client.from(table).select()
                .gt("updated_at", value: Self.iso8601Formatter.string(from: since))
                .execute().value
        } else {
            return try await client.from(table).select().execute().value
        }
    }

    // MARK: - Initial sync (register or sign-in on a device with pre-existing local data)

    /// Pushes every current local row (not just the outbox), then pulls and merges
    /// anything remote. Works uniformly whether the device had local-only data,
    /// remote-only data, both, or neither — no separate "first launch" branch needed.
    func performInitialSync() async {
        pushAllLocalData()
        await drainOutbox()
        await pullAndMerge()
    }

    private func pushAllLocalData() {
        if let users = try? modelContext.fetch(FetchDescriptor<User>()) {
            for user in users {
                if let payload = snapshotPayload(table: .profile, id: user.id, deletedAt: nil) {
                    storeOutboxEntry(table: .profile, recordID: user.id, opType: .upsert, payload: payload)
                }
            }
        }
        if let exercises = try? modelContext.fetch(FetchDescriptor<Exercise>()) {
            for exercise in exercises {
                if let payload = snapshotPayload(table: .exercise, id: exercise.id, deletedAt: nil) {
                    storeOutboxEntry(table: .exercise, recordID: exercise.id, opType: .upsert, payload: payload)
                }
            }
        }
        if let records = try? modelContext.fetch(FetchDescriptor<WorkoutRecord>()) {
            for record in records {
                if let payload = snapshotPayload(table: .workoutRecord, id: record.id, deletedAt: nil) {
                    storeOutboxEntry(table: .workoutRecord, recordID: record.id, opType: .upsert, payload: payload)
                }
            }
        }
    }

    // MARK: - Local lookups

    private func fetchUser(id: UUID) -> User? {
        var descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchExercise(id: UUID) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchWorkoutRecord(id: UUID) -> WorkoutRecord? {
        var descriptor = FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Last synced bookkeeping (per account, since a device could switch accounts)

    private func touchLastSyncedAt(ownerId: UUID? = nil) {
        guard let id = ownerId ?? client.auth.currentSession?.user.id else { return }
        let now = Date()
        lastSyncedAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastSyncedAt-\(id.uuidString)")
    }

    private static func loadLastSyncedAt(ownerId: UUID) -> Date? {
        let key = "lastSyncedAt-\(ownerId.uuidString)"
        let interval = UserDefaults.standard.double(forKey: key)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }
}
