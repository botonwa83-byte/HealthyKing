import SwiftUI
import Charts
import HealthyKingKit

struct TrendGlanceView: View {
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var metrics: [MetricType] {
        MetricType.recoveryComponents.filter { dataStore.insights[$0] != nil }
    }

    var body: some View {
        TabView {
            ForEach(metrics, id: \.self) { metric in
                MetricGlanceCard(metric: metric, insight: dataStore.insights[metric])
            }
        }
        .tabViewStyle(.page)
    }
}

private struct MetricGlanceCard: View {
    let metric: MetricType
    let insight: MetricInsight?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(metric.tintColor.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: metric.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(metric.tintColor)
            }

            Text(metric.displayName)
                .font(.caption.bold())

            if let today = insight?.today {
                Text(String(format: "%.0f %@", today, metric.unit))
                    .font(.title3.bold())
            }

            if let forecast = insight?.forecast {
                Label(directionLabel(forecast.direction), systemImage: directionIcon(forecast.direction))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let baseline = insight?.baseline, baseline.isReliable {
                Text(String(format: "基线 %.0f", baseline.mean))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }

    private func directionLabel(_ direction: TrendDirection) -> String {
        switch direction {
        case .rising: return "上升"
        case .falling: return "下降"
        case .stable: return "平稳"
        }
    }

    private func directionIcon(_ direction: TrendDirection) -> String {
        switch direction {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}
