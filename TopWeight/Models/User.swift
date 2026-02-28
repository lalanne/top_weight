import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRecord.user)
    var records: [WorkoutRecord] = []

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
