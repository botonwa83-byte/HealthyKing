import SwiftUI

@main
struct HealthyKingWatchApp: App {
    @StateObject private var dataStore = WatchHealthDataStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                TodayView()
                TrendGlanceView()
            }
            .tabViewStyle(.page)
            .environmentObject(dataStore)
        }
    }
}
