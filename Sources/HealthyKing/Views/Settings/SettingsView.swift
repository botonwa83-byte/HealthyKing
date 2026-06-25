import SwiftUI
import HealthyKingKit

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    CrossPromoCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("更多")
                }

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
            }
            .navigationTitle("设置")
        }
    }
}
