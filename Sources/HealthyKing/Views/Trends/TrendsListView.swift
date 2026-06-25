import SwiftUI
import HealthyKingKit

struct TrendsListView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    /// Metrics grouped into meaningful sections, Gentler-Streak "Health
    /// Metrics" style, rather than one flat list.
    private let groups: [(title: String, icon: String, metrics: [MetricType])] = [
        ("恢复指标", "bolt.heart", [.heartRateVariability, .restingHeartRate, .respiratoryRate, .sleepEfficiency]),
        ("睡眠与体能", "moon.zzz", [.sleepDuration, .oxygenSaturation, .vo2Max]),
        ("身体成分", "figure.stand", [.bodyMass])
    ]

    private func availableMetrics(_ metrics: [MetricType]) -> [MetricType] {
        metrics.filter { dataStore.metricSeries[$0] != nil }
    }

    private var allAvailable: [MetricType] {
        MetricType.allCases.filter { dataStore.metricSeries[$0] != nil }
    }

    /// How many metrics with a reliable baseline currently sit in a healthy band.
    private var healthyCount: (good: Int, total: Int) {
        var good = 0, total = 0
        for metric in allAvailable {
            guard let insight = dataStore.insights[metric], insight.baseline.isReliable, insight.zScore != nil else { continue }
            total += 1
            switch MetricStatus.evaluate(insight) {
            case .excellent, .normal: good += 1
            default: break
            }
        }
        return (good, total)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader

                    ForEach(groups, id: \.title) { group in
                        let metrics = availableMetrics(group.metrics)
                        if !metrics.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionHeader(title: group.title, systemImage: group.icon)
                                    .padding(.bottom, 4)
                                ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
                                    NavigationLink(value: metric) {
                                        TrendRow(
                                            metric: metric,
                                            insight: dataStore.insights[metric],
                                            series: dataStore.metricSeries[metric]
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    if index < metrics.count - 1 {
                                        Divider().opacity(0.4)
                                    }
                                }
                            }
                            .cardStyle()
                        }
                    }
                }
                .padding()
            }
            .background(ScreenBackground())
            .navigationTitle("健康指标")
            .navigationDestination(for: MetricType.self) { metric in
                MetricDestinationView(metric: metric)
            }
            .overlay {
                if allAvailable.isEmpty {
                    ContentUnavailableView("暂无趋势数据", systemImage: "chart.line.uptrend.xyaxis", description: Text("下拉刷新或稍后再来看看"))
                }
            }
            .refreshable { await dataStore.refresh() }
        }
    }

    @ViewBuilder
    private var summaryHeader: some View {
        let stats = healthyCount
        if stats.total > 0 {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(stats.good) / CGFloat(stats.total))
                        .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(stats.good)/\(stats.total)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.good == stats.total ? "状态很棒" : "整体平稳")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("\(stats.total) 项指标中，\(stats.good) 项处于你的理想范围内。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .gradientCardStyle(Brand.gradient)
        }
    }
}

private struct TrendRow: View {
    let metric: MetricType
    let insight: MetricInsight?
    let series: MetricTimeSeries?

    private var status: MetricStatus { MetricStatus.evaluate(insight) }

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
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                GradientIconChip(systemName: metric.symbolName, colors: metric.gradientColors, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 6) {
                        StatusPill(status: status)
                        if let date = insight?.latestSampleDate, insight?.today != nil {
                            Text(RelativeDay.label(for: date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 2) {
                    if let today = insight?.today {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(format(today))
                                .font(.title3.bold().monospacedDigit())
                            Text(metric.unit)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("数据积累中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: arrow)
                    .font(.subheadline.bold())
                    .foregroundStyle(arrowColor)
            }

            if let insight, let today = insight.today, insight.baseline.isReliable {
                MetricRangeBar(metric: metric, value: today, baseline: insight.baseline, status: status)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func format(_ value: Double) -> String {
        switch metric {
        case .heartRateVariability, .vo2Max, .sleepDuration, .bodyMass:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.0f", value)
        }
    }
}
