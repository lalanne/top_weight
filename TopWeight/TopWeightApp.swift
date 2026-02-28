import SwiftUI
import SwiftData

@main
struct TopWeightApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self])
    }
}
