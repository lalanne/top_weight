import Foundation

/// Wire-format DTOs for the 3 synced Supabase tables. Kept separate from the
/// SwiftData `@Model` classes so the network boundary stays explicit.

struct ProfileRow: Codable {
    var id: UUID
    var name: String
    var avatarSymbol: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case avatarSymbol = "avatar_symbol"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct ExerciseRow: Codable {
    var id: UUID
    var name: String
    var exerciseType: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case exerciseType = "exercise_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct WorkoutRecordRow: Codable {
    var id: UUID
    var userId: UUID
    var exerciseId: UUID
    var weight: Double
    var reps: Int
    var series: Int
    var date: Date
    var distance: Double?
    var isIndoor: Bool?
    var seconds: Int?
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case weight, reps, series, date, distance, seconds
        case isIndoor = "is_indoor"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - RPC parameter payloads
// Property names match the Postgres function argument names in supabase/schema.sql
// exactly (p_id, p_name, ...) so PostgREST can bind them without extra CodingKeys.

struct ProfileUpsertParams: Encodable {
    let p_id: UUID
    let p_name: String
    let p_avatar_symbol: String?
    let p_created_at: Date
    let p_updated_at: Date
    let p_deleted_at: Date?
}

struct ExerciseUpsertParams: Encodable {
    let p_id: UUID
    let p_name: String
    let p_exercise_type: String
    let p_created_at: Date
    let p_updated_at: Date
    let p_deleted_at: Date?
}

struct WorkoutRecordUpsertParams: Encodable {
    let p_id: UUID
    let p_user_id: UUID
    let p_exercise_id: UUID
    let p_weight: Double
    let p_reps: Int
    let p_series: Int
    let p_date: Date
    let p_distance: Double?
    let p_is_indoor: Bool?
    let p_seconds: Int?
    let p_updated_at: Date
    let p_deleted_at: Date?
}
