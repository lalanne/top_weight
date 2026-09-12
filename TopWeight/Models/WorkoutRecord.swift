import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var id: UUID
    var weight: Double
    var reps: Int
    var series: Int
    var date: Date
    /// Last local modification time. Drives last-write-wins cloud sync — touch on every edit.
    var updatedAt: Date = Date()

    /// For distance exercises (Running, Cycling, Walking): distance in km.
    var distance: Double?
    /// For distance exercises: true = indoors, false = outdoors.
    var isIndoor: Bool?
    /// For timed exercises (dead hangs, planks): duration in seconds.
    var seconds: Int?

    var user: User?
    var exercise: Exercise?

    var isDistanceEntry: Bool { distance != nil }

    init(
        id: UUID = UUID(),
        weight: Double = 0,
        reps: Int = 0,
        series: Int = 0,
        date: Date = Date(),
        updatedAt: Date = Date(),
        distance: Double? = nil,
        isIndoor: Bool? = nil,
        seconds: Int? = nil,
        user: User? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.series = series
        self.date = date
        self.updatedAt = updatedAt
        self.distance = distance
        self.isIndoor = isIndoor
        self.seconds = seconds
        self.user = user
        self.exercise = exercise
    }
}

extension WorkoutRecord: Identifiable {}
