import Foundation
import SwiftData

/// Strength = weight/reps/series. Distance = km + indoor/outdoor. RepsOnly = reps + series. Timed = series + seconds.
enum ExerciseType: String, Codable, CaseIterable {
    case strength
    case distance
    case repsOnly
    case timed
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
    var isTimedType: Bool { exerciseType == .timed }

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

extension Exercise {
    /// Metric used in evolution / comparison charts for a record of this exercise type.
    func chartMetricValue(for record: WorkoutRecord) -> Double {
        if isDistanceType { return record.distance ?? 0 }
        if isTimedType { return Double((record.seconds ?? 0) * record.series) }
        if isRepsOnlyType { return Double(record.reps * record.series) }
        return record.weight * Double(record.reps * record.series)
    }

    var chartYAxisLabel: String {
        if isDistanceType { return "km" }
        if isTimedType { return "total seconds" }
        if isRepsOnlyType { return "total reps" }
        return "volume (kg)"
    }
}
