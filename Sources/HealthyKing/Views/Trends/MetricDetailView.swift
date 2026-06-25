import SwiftUI
import Charts
import HealthyKingKit

struct MetricDetailView: View {
    let metric: MetricType
    let series: MetricTimeSeries?
    let insight: MetricInsight?

    private var forecastDate: Date? {
        guard let forecast = insight?.forecast, let lastDate = series?.samples.last?.date else { return nil }
        return Calendar.current.date(byAdding: .day, value: forecast.horizonDays, to: lastDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                chart
                    .frame(height: 220)
                    .cardStyle()

                if let insight {
                    summary(for: insight)
                        .cardStyle()
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: metric.symbolName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(metric.tintColor.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(insight?.today.map { String(format: "%.1f", $0) } ?? "--")
                        .font(.title.bold())
                    if insight?.today != nil {
                        Text(metric.unit)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(metric.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cardStyle()
    }

    @ViewBuilder
    private var chart: some View {
        if let samples = series?.samples, !samples.isEmpty {
            Chart {
                if let baseline = insight?.baseline, baseline.isReliable {
                    RectangleMark(
                        xStart: .value("开始", samples.first!.date),
                        xEnd: .value("结束", forecastDate ?? samples.last!.date),
                        yStart: .value("下限", baseline.normalRange.lowerBound),
                        yEnd: .value("上限", baseline.normalRange.upperBound)
                    )
                    .foregroundStyle(metric.tintColor.opacity(0.12))
                }

                ForEach(samples, id: \.date) { sample in
                    LineMark(x: .value("日期", sample.date), y: .value(metric.displayName, sample.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.tintColor.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("日期", sample.date), y: .value(metric.displayName, sample.value))
                        .foregroundStyle(metric.tintColor)
                        .symbolSize(10)
                }

                if let forecast = insight?.forecast, let forecastDate {
                    RuleMark(
                        x: .value("预测", forecastDate),
                        yStart: .value("下限", forecast.confidenceInterval.lowerBound),
                        yEnd: .value("上限", forecast.confidenceInterval.upperBound)
                    )
                    .foregroundStyle(.orange)
                    PointMark(x: .value("预测", forecastDate), y: .value("预测值", forecast.projectedValue))
                        .foregroundStyle(.orange)
                        .symbol(.diamond)
                }
            }
            .chartLegend(.hidden)
        } else {
            ContentUnavailableView("数据不足", systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    @ViewBuilder
    private func summary(for insight: MetricInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "个人基线", systemImage: "ruler")
            if insight.baseline.isReliable {
                Text(String(format: "%.1f ± %.1f %@（近%d天平均）", insight.baseline.mean, insight.baseline.standardDeviation, metric.unit, insight.baseline.windowDays))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("基线仍在校准中，再积累几天数据后会更准确。", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            changePointView(insight.changePoint)

            if let forecast = insight.forecast {
                Label(forecastText(forecast), systemImage: forecastIcon(forecast.direction))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func changePointView(_ signal: ChangePointSignal) -> some View {
        switch signal {
        case .none:
            EmptyView()
        case .shiftedUp(let magnitude):
            Label(String(format: "检测到近期持续走高，偏离基线约 %.1f 个标准差", magnitude), systemImage: "arrow.up.forward.circle.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        case .shiftedDown(let magnitude):
            Label(String(format: "检测到近期持续走低，偏离基线约 %.1f 个标准差", magnitude), systemImage: "arrow.down.forward.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func forecastText(_ forecast: ForecastResult) -> String {
        let directionText: String
        switch forecast.direction {
        case .rising: directionText = "上升"
        case .falling: directionText = "下降"
        case .stable: directionText = "保持平稳"
        }
        return String(format: "未来%d天预计%@，参考值约 %.1f %@", forecast.horizonDays, directionText, forecast.projectedValue, metric.unit)
    }

    private func forecastIcon(_ direction: TrendDirection) -> String {
        switch direction {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}
