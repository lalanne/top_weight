import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var id: UUID
    var weight: Double
    var reps: Int
    var series: Int
    var date: Date

    var user: User?
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        series: Int,
        date: Date = Date(),
        user: User? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.series = series
        self.date = date
        self.user = user
        self.exercise = exercise
    }
}
