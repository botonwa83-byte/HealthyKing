import SwiftUI
import HealthyKingKit

/// Swipe-through glance of each metric. Each card taps into the full
/// `MetricDetailView`, so this page is a fast browser, not a dead end.
struct TrendGlanceView: View {
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var metrics: [MetricType] {
        MetricType.watchDisplayOrder.filter { dataStore.insights[$0]?.today != nil }
    }

    var body: some View {
        Group {
            if metrics.isEmpty {
                ContentUnavailablePlaceholder(
                    title: "暂无趋势数据",
                    message: "授权并积累几天数据后即可查看。",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            } else {
                TabView {
                    ForEach(metrics, id: \.self) { metric in
                        NavigationLink {
                            MetricDetailView(metric: metric)
                        } label: {
                            MetricGlanceCard(metric: metric, insight: dataStore.insights[metric])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        .navigationTitle("趋势")
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

            Text(metric.shortName)
                .font(.caption.bold())

            if let today = insight?.today {
                Text(String(format: "%@ %@", metric.formattedValue(today), metric.unit))
                    .font(.title3.bold())
            }

            if let dayText = relativeDayText(for: insight?.latestSampleDate) {
                Text(dayText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let baseline = insight?.baseline, baseline.isReliable {
                Text(String(format: "基线 %@", metric.formattedValue(baseline.mean)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Label("查看详情", systemImage: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 6)
    }
}
