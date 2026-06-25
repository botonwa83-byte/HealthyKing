import SwiftUI
import Charts
import HealthyKingKit

/// Per-metric detail reachable by tapping a row on the Today screen. Shows
/// the current reading (with its real date), the personal baseline, any
/// change-point signal, the short-horizon forecast, and a trailing chart.
struct MetricDetailView: View {
    let metric: MetricType
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var insight: MetricInsight? { dataStore.insights[metric] }
    private var series: MetricTimeSeries? { dataStore.seriesByMetric[metric] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                chart
                baselineCard
                changePointView
                forecastView
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(metric.shortName)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: metric.symbolName)
                    .foregroundStyle(metric.tintColor)
                Text(metric.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(insight?.today.map { metric.formattedValue($0) } ?? "—")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(metric.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let dayText = relativeDayText(for: insight?.latestSampleDate) {
                Text("数据来自\(dayText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("近期暂无数据")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chart: some View {
        if let samples = series?.samples, samples.count >= 2 {
            Chart {
                if let baseline = insight?.baseline, baseline.isReliable {
                    RectangleMark(
                        yStart: .value("下限", baseline.normalRange.lowerBound),
                        yEnd: .value("上限", baseline.normalRange.upperBound)
                    )
                    .foregroundStyle(metric.tintColor.opacity(0.12))
                }
                ForEach(samples, id: \.date) { sample in
                    LineMark(x: .value("日期", sample.date), y: .value(metric.shortName, sample.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.tintColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 90)
        } else {
            Text("数据不足，无法绘制趋势")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var baselineCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("个人基线", systemImage: "ruler")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            if let baseline = insight?.baseline, baseline.isReliable {
                Text(String(format: "%@ ± %@ %@", metric.formattedValue(baseline.mean), metric.formattedValue(baseline.standardDeviation), metric.unit))
                    .font(.footnote)
                Text("近 \(baseline.windowDays) 天平均")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("基线校准中，再积累几天数据会更准。")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var changePointView: some View {
        switch insight?.changePoint {
        case .shiftedUp(let magnitude):
            Label(String(format: "近期持续走高，约偏离基线 %.1f 个标准差", magnitude), systemImage: "arrow.up.forward.circle.fill")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .shiftedDown(let magnitude):
            Label(String(format: "近期持续走低，约偏离基线 %.1f 个标准差", magnitude), systemImage: "arrow.down.forward.circle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var forecastView: some View {
        if let forecast = insight?.forecast {
            Label(forecastText(forecast), systemImage: forecastIcon(forecast.direction))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func forecastText(_ forecast: ForecastResult) -> String {
        let direction: String
        switch forecast.direction {
        case .rising: direction = "上升"
        case .falling: direction = "下降"
        case .stable: direction = "保持平稳"
        }
        return String(format: "未来 %d 天预计%@，约 %@ %@", forecast.horizonDays, direction, metric.formattedValue(forecast.projectedValue), metric.unit)
    }

    private func forecastIcon(_ direction: TrendDirection) -> String {
        switch direction {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}
