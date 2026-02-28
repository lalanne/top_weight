import Foundation
import SwiftData

/// Strength = weight/reps/series. Distance = km + indoor/outdoor. RepsOnly = just reps (Push-ups, Pull-ups, etc.)
enum ExerciseType: String, Codable, CaseIterable {
    case strength
    case distance
    case repsOnly
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var exerciseTypeRawValue: String = "strength"
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRecord.exercise)
    var records: [WorkoutRecord] = []

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRawValue) ?? .strength }
        set { exerciseTypeRawValue = newValue.rawValue }
    }

    var isDistanceType: Bool { exerciseType == .distance }
    var isRepsOnlyType: Bool { exerciseType == .repsOnly }

    init(
        id: UUID = UUID(),
        name: String,
        exerciseType: ExerciseType = .strength,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.exerciseTypeRawValue = exerciseType.rawValue
        self.createdAt = createdAt
    }
}
