import Foundation
import SwiftData

/// The 3 Supabase tables that get synced. `PersonalBest` is intentionally
/// excluded — it's a derived cache, rebuilt locally after every merge.
enum SyncTable: String, Codable, Sendable {
    case profile = "profiles"
    case exercise = "exercises"
    case workoutRecord = "workout_records"
}

enum SyncOpType: String, Codable {
    case upsert
    case delete
}

/// A durable, offline-safe outbox: a save never requires network. Local
/// mutations queue here (deduped per record) and push when a `SyncService`
/// drain succeeds; failed drains simply leave the entry for the next attempt.
@Model
final class SyncOutboxEntry {
    var id: UUID = UUID()
    var tableRawValue: String = SyncTable.workoutRecord.rawValue
    var recordID: UUID = UUID()
    var opTypeRawValue: String = SyncOpType.upsert.rawValue
    /// JSON-encoded row snapshot (`ProfileRow`/`ExerciseRow`/`WorkoutRecordRow`), captured
    /// at enqueue time so a drain never needs to re-fetch an already-deleted local object.
    var payload: Data = Data()
    var enqueuedAt: Date = Date()

    var table: SyncTable {
        get { SyncTable(rawValue: tableRawValue) ?? .workoutRecord }
        set { tableRawValue = newValue.rawValue }
    }

    var opType: SyncOpType {
        get { SyncOpType(rawValue: opTypeRawValue) ?? .upsert }
        set { opTypeRawValue = newValue.rawValue }
    }

    init(table: SyncTable, recordID: UUID, opType: SyncOpType, payload: Data) {
        self.id = UUID()
        self.tableRawValue = table.rawValue
        self.recordID = recordID
        self.opTypeRawValue = opType.rawValue
        self.payload = payload
        self.enqueuedAt = Date()
    }
}
