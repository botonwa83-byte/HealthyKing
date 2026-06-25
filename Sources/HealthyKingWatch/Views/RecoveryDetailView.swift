import SwiftUI
import HealthyKingKit

/// Explains the composite recovery score by breaking it into each metric's
/// signed point contribution — the whole point of this app versus an opaque
/// commercial readiness number.
struct RecoveryDetailView: View {
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var recovery: RecoveryScoreResult? { dataStore.recovery }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                RecoveryRing(score: recovery?.score, band: recovery?.band, lineWidth: 11)
                    .frame(width: 110, height: 110)
                    .padding(.top, 4)

                if let recovery, !recovery.isReliable {
                    Text("数据仍在校准，分数会随天数增加越来越准。")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Text("分数 = 50 基准分 ± 各项贡献")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    ForEach(MetricType.recoveryComponents, id: \.self) { metric in
                        if let component = recovery?.components.first(where: { $0.metric == metric }) {
                            componentRow(component)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("恢复评分")
    }

    @ViewBuilder
    private func componentRow(_ component: RecoveryComponent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: component.metric.symbolName)
                .font(.caption2)
                .foregroundStyle(component.metric.tintColor)
                .frame(width: 16)
            Text(component.metric.shortName)
                .font(.caption2)
            Spacer()
            if component.zScore != nil {
                Text(String(format: "%+.0f", component.contributionPoints.rounded()))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(contributionColor(component.contributionPoints))
            } else {
                Text("数据不足")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func contributionColor(_ points: Double) -> Color {
        if points > 0.5 { return .green }
        if points < -0.5 { return .orange }
        return .secondary
    }
}
