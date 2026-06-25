import SwiftUI
import HealthyKingKit

struct TrendsListView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    private var availableMetrics: [MetricType] {
        MetricType.allCases.filter { dataStore.metricSeries[$0] != nil }
    }

    var body: some View {
        NavigationStack {
            List(availableMetrics, id: \.self) { metric in
                NavigationLink(value: metric) {
                    TrendRow(metric: metric, insight: dataStore.insights[metric])
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("趋势")
            .navigationDestination(for: MetricType.self) { metric in
                MetricDetailView(
                    metric: metric,
                    series: dataStore.metricSeries[metric],
                    insight: dataStore.insights[metric]
                )
            }
            .overlay {
                if availableMetrics.isEmpty {
                    ContentUnavailableView("暂无趋势数据", systemImage: "chart.line.uptrend.xyaxis", description: Text("下拉刷新或稍后再来看看"))
                }
            }
            .refreshable { await dataStore.refresh() }
        }
    }
}

private struct TrendRow: View {
    let metric: MetricType
    let insight: MetricInsight?

    private var arrow: String {
        switch insight?.forecast?.direction {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        case nil: return "minus"
        }
    }

    private var arrowColor: Color {
        switch insight?.forecast?.direction {
        case .rising: return .green
        case .falling: return .orange
        case .stable, nil: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.symbolName)
                .font(.subheadline)
                .foregroundStyle(metric.tintColor)
                .frame(width: 30, height: 30)
                .background(metric.tintColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName)
                if let today = insight?.today {
                    Text(String(format: "%.1f %@", today, metric.unit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("数据积累中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: arrow)
                .font(.subheadline.bold())
                .foregroundStyle(arrowColor)
        }
        .padding(.vertical, 4)
    }
}
