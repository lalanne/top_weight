import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var id: UUID
    var weight: Double
    var reps: Int
    var series: Int
    var date: Date

    /// For distance exercises (Running, Cycling, Walking): distance in km.
    var distance: Double?
    /// For distance exercises: true = indoors, false = outdoors.
    var isIndoor: Bool?

    var user: User?
    var exercise: Exercise?

    var isDistanceEntry: Bool { distance != nil }

    init(
        id: UUID = UUID(),
        weight: Double = 0,
        reps: Int = 0,
        series: Int = 0,
        date: Date = Date(),
        distance: Double? = nil,
        isIndoor: Bool? = nil,
        user: User? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.series = series
        self.date = date
        self.distance = distance
        self.isIndoor = isIndoor
        self.user = user
        self.exercise = exercise
    }
}
