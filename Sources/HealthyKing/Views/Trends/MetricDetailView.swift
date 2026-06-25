import SwiftUI
import Charts
import HealthyKingKit

/// Selectable look-back window for the trend chart.
enum TrendRange: String, CaseIterable, Identifiable {
    case week, month, quarter, year, threeYears

    var id: String { rawValue }

    /// The common ranges shown as segments; longer ones live behind "更多".
    static let shortRanges: [TrendRange] = [.week, .month, .quarter]
    static let longRanges: [TrendRange] = [.year, .threeYears]
    var isLong: Bool { Self.longRanges.contains(self) }

    var title: String {
        switch self {
        case .week: return "一周"
        case .month: return "一月"
        case .quarter: return "三月"
        case .year: return "一年"
        case .threeYears: return "三年"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .threeYears: return 1095
        }
    }

    /// Heading for the period-summary card, distinct per range.
    var periodTitle: String {
        switch self {
        case .week: return "近一周概览"
        case .month: return "近一月概览"
        case .quarter: return "近三月概览"
        case .year: return "近一年概览"
        case .threeYears: return "近三年概览"
        }
    }

    /// What the net change is measured against, distinct per range.
    var comparisonAnchor: String {
        switch self {
        case .week: return "一周前"
        case .month: return "一月前"
        case .quarter: return "三月前"
        case .year: return "一年前"
        case .threeYears: return "三年前"
        }
    }

    /// A range-specific interpretation line, so the copy differs meaningfully
    /// between ranges instead of repeating.
    var interpretation: String {
        switch self {
        case .week: return "近一周更适合观察短期波动，留意是否出现连续几天的明显偏离。"
        case .month: return "一个月的走向能反映近期状态的整体变化，单日起伏可忽略。"
        case .quarter: return "三个月属于长期趋势，更能体现训练与生活方式带来的累积影响。"
        case .year: return "一年的跨度能体现季节性变化与长期健康走向。"
        case .threeYears: return "三年属于超长期回顾，适合观察整体健康基线的演变。"
        }
    }
}

/// Range selector: segments for the common windows, plus a "更多" menu that
/// reveals the longer 一年 / 三年 ranges. Shared by every trend chart.
struct TrendRangePicker: View {
    @Binding var range: TrendRange

    var body: some View {
        HStack(spacing: 8) {
            Picker("时间范围", selection: $range.animation(.easeInOut)) {
                ForEach(TrendRange.shortRanges) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(TrendRange.longRanges) { option in
                    Button {
                        withAnimation(.easeInOut) { range = option }
                    } label: {
                        if range == option {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(range.isLong ? range.title : "更多")
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(range.isLong ? Color.white : Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(range.isLong ? Color.accentColor : Color.accentColor.opacity(0.14), in: Capsule())
            }
        }
    }
}

struct MetricDetailView: View {
    let metric: MetricType
    let series: MetricTimeSeries?
    let insight: MetricInsight?

    @State private var range: TrendRange = .week

    /// Samples limited to the currently selected look-back window.
    private var visibleSamples: [DailySample] {
        guard let samples = series?.samples, let last = samples.last?.date else { return [] }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: last) else { return samples }
        return samples.filter { $0.date >= cutoff }
    }

    private var forecastDate: Date? {
        guard let forecast = insight?.forecast, let lastDate = visibleSamples.last?.date else { return nil }
        return Calendar.current.date(byAdding: .day, value: forecast.horizonDays, to: lastDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                rangePicker

                chart
                    .frame(height: 230)
                    .cardStyle()

                periodSummary
                    .cardStyle()

                if let insight {
                    todayPositionCard(insight)
                    insightCard(insight)
                }
            }
            .padding()
        }
        .background(ScreenBackground(tint: metric.gradientColors.last ?? Brand.primary))
        .navigationTitle(metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(insight?.today.map { String(format: "%.1f", $0) } ?? "--")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if insight?.today != nil {
                        Text(metric.unit)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            Spacer()
            Image(systemName: metric.symbolName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .gradientCardStyle(metric.gradientColors)
    }

    private var rangePicker: some View {
        Picker("时间范围", selection: $range.animation(.easeInOut)) {
            ForEach(TrendRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chart: some View {
        let samples = visibleSamples
        if !samples.isEmpty {
            Chart {
                if let baseline = insight?.baseline, baseline.isReliable {
                    RectangleMark(
                        xStart: .value("开始", samples.first!.date),
                        xEnd: .value("结束", forecastDate ?? samples.last!.date),
                        yStart: .value("下限", baseline.normalRange.lowerBound),
                        yEnd: .value("上限", baseline.normalRange.upperBound)
                    )
                    .foregroundStyle((metric.gradientColors.last ?? Brand.primary).opacity(0.10))
                }

                if let avg = windowStats?.average {
                    RuleMark(y: .value("平均", avg))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("平均 \(fmt(avg))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }

                ForEach(samples, id: \.date) { sample in
                    AreaMark(x: .value("日期", sample.date), y: .value(metric.displayName, sample.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(colors: [(metric.gradientColors.last ?? Brand.primary).opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("日期", sample.date), y: .value(metric.displayName, sample.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }

                if let last = samples.last {
                    PointMark(x: .value("日期", last.date), y: .value(metric.displayName, last.value))
                        .foregroundStyle(metric.gradientColors.last ?? Brand.primary)
                        .symbolSize(70)
                        .annotation(position: .top) {
                            Text(fmt(last.value))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(metric.gradientColors.last ?? Brand.primary)
                        }
                }

                if let forecast = insight?.forecast, let forecastDate {
                    RuleMark(
                        x: .value("预测", forecastDate),
                        yStart: .value("下限", forecast.confidenceInterval.lowerBound),
                        yEnd: .value("上限", forecast.confidenceInterval.upperBound)
                    )
                    .foregroundStyle(.orange.opacity(0.6))
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

    // MARK: - Period summary (range-aware)

    private struct WindowStats {
        let average: Double
        let low: Double
        let high: Double
        let net: Double
        let count: Int
    }

    private var windowStats: WindowStats? {
        let samples = visibleSamples
        guard samples.count >= 2 else { return nil }
        let values = samples.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        return WindowStats(
            average: avg,
            low: values.min() ?? avg,
            high: values.max() ?? avg,
            net: (samples.last?.value ?? 0) - (samples.first?.value ?? 0),
            count: values.count
        )
    }

    @ViewBuilder
    private var periodSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: range.periodTitle, systemImage: "calendar")

            if let stats = windowStats {
                HStack(spacing: 0) {
                    statItem("平均", value: fmt(stats.average))
                    Divider().frame(height: 30)
                    statItem("最低", value: fmt(stats.low))
                    Divider().frame(height: 30)
                    statItem("最高", value: fmt(stats.high))
                    Divider().frame(height: 30)
                    statItem("天数", value: "\(stats.count)")
                }

                Label(changeText(stats.net), systemImage: changeIcon(stats.net))
                    .font(.caption)
                    .foregroundStyle(changeColor(stats.net))

                Text(range.interpretation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("该时间范围内的数据还不足以汇总，多积累几天后再来看看。", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statItem(_ title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Net change over the visible window, worded against the range's anchor.
    private func changeText(_ net: Double) -> String {
        let rounded = (fmt(abs(net)) as NSString).doubleValue
        if rounded == 0 {
            return "较\(range.comparisonAnchor)基本持平"
        }
        let direction = net > 0 ? "上升" : "下降"
        return "较\(range.comparisonAnchor)\(direction) \(fmt(abs(net))) \(metric.unit)"
    }

    private func changeIcon(_ net: Double) -> String {
        let rounded = (fmt(abs(net)) as NSString).doubleValue
        if rounded == 0 { return "equal.circle" }
        return net > 0 ? "arrow.up.right.circle" : "arrow.down.right.circle"
    }

    private func changeColor(_ net: Double) -> Color {
        let rounded = (fmt(abs(net)) as NSString).doubleValue
        if rounded == 0 { return .secondary }
        // A rise is "good" only when higher is better for this metric.
        let isGood = (net > 0) == metric.higherIsBetter
        return isGood ? .green : .orange
    }

    private func fmt(_ value: Double) -> String {
        switch metric {
        case .heartRateVariability, .vo2Max, .sleepDuration, .bodyMass:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.0f", value)
        }
    }

    // MARK: - Today's position vs. personal baseline (visual)

    @ViewBuilder
    private func todayPositionCard(_ insight: MetricInsight) -> some View {
        if let today = insight.today, insight.baseline.isReliable {
            let status = MetricStatus.evaluate(insight)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "今日位置", systemImage: "scope")
                    Spacer()
                    StatusPill(status: status)
                }
                MetricRangeBar(metric: metric, value: today, baseline: insight.baseline, status: status)
                Text(String(format: "正常范围 %@–%@ %@ · 个人基线 %@ ± %@（近%d天）",
                            fmt(insight.baseline.normalRange.lowerBound),
                            fmt(insight.baseline.normalRange.upperBound),
                            metric.unit,
                            fmt(insight.baseline.mean),
                            fmt(insight.baseline.standardDeviation),
                            insight.baseline.windowDays))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .cardStyle()
        } else if !insight.baseline.isReliable {
            Label("基线仍在校准中，再积累几天数据后会更准确。", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.orange)
                .cardStyle()
        }
    }

    // MARK: - Trend insights (visual badges, not a list)

    @ViewBuilder
    private func insightCard(_ insight: MetricInsight) -> some View {
        let badges = insightBadges(insight)
        if !badges.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "趋势洞察", systemImage: "sparkles")
                ForEach(badges) { badge in
                    HStack(spacing: 8) {
                        Image(systemName: badge.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(badge.color)
                            .frame(width: 22, height: 22)
                            .background(badge.color.opacity(0.14), in: Circle())
                        Text(badge.text)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .cardStyle()
        }
    }

    private struct InsightBadge: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let text: String
    }

    private func insightBadges(_ insight: MetricInsight) -> [InsightBadge] {
        var badges: [InsightBadge] = []
        switch insight.changePoint {
        case .none:
            break
        case .shiftedUp(let magnitude):
            badges.append(InsightBadge(icon: "arrow.up.forward.circle.fill", color: .blue,
                text: String(format: "近期持续走高，偏离基线约 %.1f 个标准差", magnitude)))
        case .shiftedDown(let magnitude):
            badges.append(InsightBadge(icon: "arrow.down.forward.circle.fill", color: .orange,
                text: String(format: "近期持续走低，偏离基线约 %.1f 个标准差", magnitude)))
        }
        if let forecast = insight.forecast {
            let directionText: String
            let icon: String
            switch forecast.direction {
            case .rising: directionText = "上升"; icon = "arrow.up.right"
            case .falling: directionText = "下降"; icon = "arrow.down.right"
            case .stable: directionText = "保持平稳"; icon = "arrow.right"
            }
            badges.append(InsightBadge(icon: icon, color: Color(hex: 0x7C5CFF),
                text: String(format: "未来%d天预计%@，参考值约 %@ %@", forecast.horizonDays, directionText, fmt(forecast.projectedValue), metric.unit)))
        }
        return badges
    }
}
