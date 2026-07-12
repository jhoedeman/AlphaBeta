import SwiftData
import SwiftUI

@main
struct AlphaBetaApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([UserPreferences.self, ItemProgress.self, QuizSession.self, StreakRecord.self])
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            // UI tests need a blank slate every launch — a stock container
            // silently carries forward whatever SwiftData state a previous
            // manual test session left behind (e.g. a stray palette
            // override), making tests flaky depending on run order.
            modelContainer = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        } else if let cloudContainer = try? ModelContainer(for: schema, configurations: [ModelConfiguration(cloudKitDatabase: .automatic)]) {
            modelContainer = cloudContainer
        } else if let localContainer = try? ModelContainer(for: schema, configurations: [ModelConfiguration(cloudKitDatabase: .none)]) {
            // iCloud unavailable (e.g. simulator without an account) — the
            // app must still fully function locally (SPEC §1).
            modelContainer = localContainer
        } else {
            modelContainer = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
