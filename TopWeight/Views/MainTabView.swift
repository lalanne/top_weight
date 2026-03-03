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
            TopsView()
                .tabItem {
                    Label("Tops", systemImage: "trophy.fill")
                }
            EvolutionView()
                .tabItem {
                    Label("Evolution", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [User.self, Exercise.self, WorkoutRecord.self, PersonalBest.self], inMemory: true)
}
