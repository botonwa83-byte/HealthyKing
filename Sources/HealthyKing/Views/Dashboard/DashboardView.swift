import SwiftUI
import HealthyKingKit

struct DashboardView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RecoveryRingView(result: dataStore.recovery)
                        .padding(.top, 8)

                    if let recovery = dataStore.recovery {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "评分构成", systemImage: "list.bullet.rectangle")
                            ForEach(recovery.components, id: \.metric) { component in
                                RecoveryComponentRow(component: component)
                            }
                        }
                        .cardStyle()
                    }

                    TrainingLoadCard(result: dataStore.trainingLoad)

                    if let error = dataStore.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .cardStyle()
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable { await dataStore.refresh() }
            .navigationTitle("今日概览")
            .overlay {
                if dataStore.isLoading && !dataStore.hasLoadedOnce {
                    ProgressView("加载健康数据…")
                }
            }
        }
        .task {
            if !dataStore.hasLoadedOnce {
                await dataStore.refresh()
            }
        }
    }
}
