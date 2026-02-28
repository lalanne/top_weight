import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "plus.circle.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self], inMemory: true)
}
