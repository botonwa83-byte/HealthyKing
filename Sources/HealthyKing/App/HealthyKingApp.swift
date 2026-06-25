import SwiftUI

@main
struct HealthyKingApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var dataStore = HealthDataStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(dataStore)
                } else {
                    OnboardingView(onFinished: { hasCompletedOnboarding = true })
                        .environmentObject(dataStore)
                }
            }
        }
    }
}
