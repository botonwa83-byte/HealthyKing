import SwiftUI

@main
struct HealthyKingWatchApp: App {
    @StateObject private var dataStore = WatchHealthDataStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { TodayView() }
                NavigationStack { TrendGlanceView() }
            }
            .tabViewStyle(.page)
            .environmentObject(dataStore)
        }
    }
}
