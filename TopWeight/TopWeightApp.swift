import SwiftUI
import SwiftData

@main
struct TopWeightApp: App {
    @State private var authService: AuthService
    private let syncService: SyncService
    private let container: ModelContainer

    init() {
        let schema = Schema([User.self, Exercise.self, WorkoutRecord.self, PersonalBest.self, SyncOutboxEntry.self])
        container = try! ModelContainer(for: schema)
        let auth = AuthService()
        _authService = State(initialValue: auth)
        syncService = SyncService(client: auth.client, modelContext: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(syncService)
        }
        .modelContainer(container)
    }
}

private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthService.self) private var authService
    @Environment(SyncService.self) private var syncService

    var body: some View {
        MainTabView()
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, authService.isAuthenticated else { return }
                Task {
                    await syncService.drainOutbox()
                    await syncService.pullAndMerge()
                }
            }
            .task {
                guard authService.isAuthenticated else { return }
                await syncService.drainOutbox()
                await syncService.pullAndMerge()
            }
    }
}
