import SwiftUI
import HealthyKingKit

struct SettingsView: View {
    private static let developerAppsURL = URL(string: "https://apps.apple.com/us/developer/%E5%B3%B0-%E7%8E%8B/id1896489503")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(ComplianceCopy.onboardingDisclaimer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.tint)
                    }
                } header: {
                    Text("关于本应用")
                }

                Section {
                    Label {
                        Text(ComplianceCopy.privacyPolicySummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.tint)
                    }
                    Button {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("打开系统健康App隐私设置", systemImage: "heart.text.square")
                    }
                } header: {
                    Text("隐私")
                }

                Section {
                    HStack {
                        Label("版本", systemImage: "number.circle")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        UIApplication.shared.open(Self.developerAppsURL)
                    } label: {
                        Label("发现我的其他应用", systemImage: "square.grid.2x2.fill")
                    }
                } header: {
                    Text("更多")
                } footer: {
                    Text("在 App Store 查看同一开发者发布的其他工具。")
                }
            }
            .navigationTitle("设置")
        }
    }
}
