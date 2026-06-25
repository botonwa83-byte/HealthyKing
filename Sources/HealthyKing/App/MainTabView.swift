import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("概览", systemImage: "heart.fill") }

            TrendsListView()
                .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }

            TrainingLoadView()
                .tabItem { Label("训练负荷", systemImage: "figure.run") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
