import SwiftUI
import HealthyKingKit

struct DashboardView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    /// Every tracked metric, in a stable display order, so the home page is a
    /// *complete* picture rather than only the metrics that happen to have a
    /// value today. Metrics still calibrating render as "暂无数据".
    private var orderedMetrics: [MetricType] {
        MetricType.watchDisplayOrder
    }

    /// The day the freshest core overnight metric was recorded — almost always
    /// "昨天" by the time the user opens the app. Drives the header subtitle.
    private var dataDate: Date? {
        MetricType.recoveryComponents
            .compactMap { dataStore.insights[$0]?.latestSampleDate }
            .max()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateBanner

                    RecoveryRingView(result: dataStore.recovery)

                    TrainingLoadCard(result: dataStore.trainingLoad)

                    todayActivityCard

                    recommendationCard

                    metricsCard

                    if let recovery = dataStore.recovery {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "评分构成", systemImage: "list.bullet.rectangle")
                            ForEach(recovery.components, id: \.metric) { component in
                                RecoveryComponentRow(component: component)
                            }
                        }
                        .cardStyle()
                    }

                    if let error = dataStore.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .cardStyle()
                    }
                }
                .padding()
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .refreshable { await dataStore.refresh() }
            .navigationDestination(for: MetricType.self) { metric in
                MetricDestinationView(metric: metric)
            }
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

    // MARK: - Header

    @ViewBuilder
    private var dateBanner: some View {
        if let dataDate {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("健康日报 · \(RelativeDay.label(for: dataDate))")
                        .font(.subheadline.weight(.semibold))
                    Text(Self.longDateFormatter.string(from: dataDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    // MARK: - Today's activity (Gentler-Streak "today" numbers)

    @ViewBuilder
    private var todayActivityCard: some View {
        if let activity = dataStore.todayActivity, activity.hasData {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "今日活动", systemImage: "flame.fill")
                HStack(spacing: 10) {
                    ActivityTile(
                        icon: "figure.walk",
                        value: stepFormatter.string(from: NSNumber(value: Int(activity.steps))) ?? "\(Int(activity.steps))",
                        unit: "步",
                        colors: [Color(hex: 0x34E0A1), Color(hex: 0x11998E)]
                    )
                    ActivityTile(
                        icon: "flame.fill",
                        value: "\(Int(activity.activeEnergyKilocalories))",
                        unit: "千卡",
                        colors: [Color(hex: 0xFF6B6B), Color(hex: 0xE0102A)]
                    )
                    ActivityTile(
                        icon: "stopwatch.fill",
                        value: "\(Int(activity.exerciseMinutes))",
                        unit: "锻炼分",
                        colors: [Color(hex: 0x4FACFE), Color(hex: 0x2563EB)]
                    )
                }
            }
            .cardStyle()
        }
    }

    private var stepFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }

    // MARK: - Recommendation (Gentler-Streak "Go Gentler")

    @ViewBuilder
    private var recommendationCard: some View {
        if let recommendation = DailyRecommendation.make(
            recovery: dataStore.recovery,
            load: dataStore.trainingLoad
        ) {
            HStack(spacing: 14) {
                Image(systemName: recommendation.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: recommendation.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日建议")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(recommendation.headline)
                        .font(.subheadline.weight(.bold))
                    Text(recommendation.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
    }

    // MARK: - Metrics

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "全部健康指标", systemImage: "waveform.path.ecg")
                .padding(.bottom, 4)
            ForEach(Array(orderedMetrics.enumerated()), id: \.element) { index, metric in
                NavigationLink(value: metric) {
                    DetailedMetricRow(
                        metric: metric,
                        insight: dataStore.insights[metric],
                        series: dataStore.metricSeries[metric]
                    )
                }
                .buttonStyle(.plain)
                if index < orderedMetrics.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Detailed metric row

/// A rich, single metric row: gradient icon, value + unit, status pill,
/// recorded-day label, personal-baseline range and a sparkline — everything
/// needed to read one metric's health status without leaving the home page.
private struct DetailedMetricRow: View {
    let metric: MetricType
    let insight: MetricInsight?
    let series: MetricTimeSeries?

    private var recentSamples: [DailySample] {
        guard let series else { return [] }
        return Array(series.samples.suffix(21))
    }

    private var status: MetricStatus { MetricStatus.evaluate(insight) }

    private var baselineRangeText: String? {
        guard let baseline = insight?.baseline, baseline.isReliable else { return nil }
        let range = baseline.normalRange
        return "基线 \(format(range.lowerBound))–\(format(range.upperBound)) \(metric.unit)"
    }

    private var recordedLabel: String? {
        insight?.latestSampleDate.map { RelativeDay.label(for: $0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            GradientIconChip(systemName: metric.symbolName, colors: metric.gradientColors, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    StatusPill(status: status)
                    if let recordedLabel, insight?.today != nil {
                        Text(recordedLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let baselineRangeText {
                    Text(baselineRangeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if recentSamples.count >= 3 {
                MiniAreaChart(samples: recentSamples, colors: metric.gradientColors)
                    .frame(width: 58, height: 34)
            }

            VStack(alignment: .trailing, spacing: 2) {
                if let today = insight?.today {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(format(today))
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text(metric.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    trendArrow
                } else {
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
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

    @ViewBuilder
    private var trendArrow: some View {
        switch insight?.forecast?.direction {
        case .rising:
            Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(.green)
        case .falling:
            Image(systemName: "arrow.down.right").font(.caption.bold()).foregroundStyle(.orange)
        case .stable:
            Image(systemName: "arrow.right").font(.caption.bold()).foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - Activity tile

/// One big-number activity stat (steps / energy / exercise) with a gradient
/// icon — the home-screen "today" tiles.
private struct ActivityTile: View {
    let icon: String
    let value: String
    let unit: String
    let colors: [Color]

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Daily recommendation ("Go Gentler")

/// A kind, actionable suggestion for today derived from recovery readiness and
/// training load — the app's take on Gentler Streak's "Go Gentler" card.
struct DailyRecommendation {
    let icon: String
    let headline: String
    let detail: String
    let colors: [Color]

    static func make(recovery: RecoveryScoreResult?, load: TrainingLoadResult?) -> DailyRecommendation? {
        let band = recovery?.band
        let zone = load?.zone

        // Highest-priority signal: clearly under-recovered or overloaded → rest.
        if band == .needsRest || zone == .high {
            return DailyRecommendation(
                icon: "leaf.fill",
                headline: "今天以恢复为主",
                detail: "安排轻松散步、拉伸或瑜伽 20–30 分钟，给身体充分修复的时间。",
                colors: [Color(hex: 0x34E0A1), Color(hex: 0x11998E)]
            )
        }

        // Primed and not overloaded → green light for a harder session.
        if band == .primed && (zone == .optimal || zone == .detraining || zone == nil) {
            return DailyRecommendation(
                icon: "flame.fill",
                headline: "状态正好，适合发力",
                detail: "可以安排一次中高强度训练，跑步或力量 40–50 分钟，注意循序渐进。",
                colors: [Color(hex: 0xFF5E62), Color(hex: 0xDD2476)]
            )
        }

        // Elevated load but otherwise fine → keep it moderate.
        if zone == .elevated {
            return DailyRecommendation(
                icon: "figure.cooldown",
                headline: "适度活动，控制强度",
                detail: "近期负荷偏高，今天选择中低强度有氧 30 分钟，避免连续高强度。",
                colors: [Color(hex: 0xFFB347), Color(hex: 0xFF8008)]
            )
        }

        // Default: steady, ordinary day.
        guard band != nil || zone != nil else { return nil }
        return DailyRecommendation(
            icon: "figure.run",
            headline: "保持常规节奏",
            detail: "状态平稳，适合常规有氧或力量训练 30–40 分钟，按计划进行即可。",
            colors: [Color(hex: 0x4FACFE), Color(hex: 0x2563EB)]
        )
    }
}
