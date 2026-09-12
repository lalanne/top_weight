import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var name: String
    var createdAt: Date
    /// Last local modification time. Drives last-write-wins cloud sync — touch on every edit.
    var updatedAt: Date = Date()

    /// Custom photo from camera or library (JPEG data).
    var photoData: Data?
    /// Preset avatar SF Symbol name when photoData is nil (e.g. "person.fill", "figure.run").
    var avatarSymbol: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRecord.user)
    var records: [WorkoutRecord] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        photoData: Data? = nil,
        avatarSymbol: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.photoData = photoData
        self.avatarSymbol = avatarSymbol
    }
}
