import SwiftUI
import Charts
import HealthyKingKit

/// Routes a tapped metric to the right detail screen: a rich, native-Health-
/// style sleep breakdown for the sleep metrics, the generic trend detail for
/// everything else. Shared by the dashboard and the trends list.
struct MetricDestinationView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    let metric: MetricType

    var body: some View {
        if metric == .sleepDuration || metric == .sleepEfficiency {
            SleepDetailView(
                nights: dataStore.sleepNights,
                durationSeries: dataStore.metricSeries[.sleepDuration]
            )
        } else {
            MetricDetailView(
                metric: metric,
                series: dataStore.metricSeries[metric],
                insight: dataStore.insights[metric]
            )
        }
    }
}

// MARK: - Sleep stages (display)

private enum SleepStage: CaseIterable {
    case deep, core, rem, awake

    var name: String {
        switch self {
        case .awake: return "清醒"
        case .rem: return "快速眼动"
        case .core: return "核心睡眠"
        case .deep: return "深度睡眠"
        }
    }

    var color: Color {
        switch self {
        case .awake: return Color(hex: 0xFF9F0A)
        case .rem: return Color(hex: 0x64D2FF)
        case .core: return Color(hex: 0x0A84FF)
        case .deep: return Color(hex: 0x5E5CE6)
        }
    }

    func duration(in night: SleepNight) -> TimeInterval {
        switch self {
        case .awake: return night.awake
        case .rem: return night.rem
        // Fold "unspecified asleep" into core so older data still totals up.
        case .core: return night.core + night.unspecified
        case .deep: return night.deep
        }
    }

    static func from(_ kind: SleepStageKind) -> SleepStage {
        switch kind {
        case .awake: return .awake
        case .rem: return .rem
        case .deep: return .deep
        case .core, .unspecified: return .core
        }
    }

    /// Bottom-to-top ordering on the hypnogram's category axis.
    static var axisOrder: [String] { [SleepStage.deep, .core, .rem, .awake].map(\.name) }
}

// MARK: - Sleep detail

struct SleepDetailView: View {
    let nights: [SleepNight]
    let durationSeries: MetricTimeSeries?

    @State private var range: TrendRange = .week

    private var latest: SleepNight? { nights.last }

    private var hasTrendData: Bool { (durationSeries?.samples.count ?? 0) >= 2 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let latest {
                    hero(latest)
                    if !hypnogramSegments(latest).isEmpty {
                        hypnogramCard(latest)
                        stageChips(latest)
                    }
                    statStrip(latest)
                }

                if hasTrendData {
                    trendCard
                }

                if latest == nil && !hasTrendData {
                    ContentUnavailableView("暂无睡眠数据", systemImage: "bed.double", description: Text("佩戴 Apple Watch 入睡后即可看到详细分析"))
                        .cardStyle()
                }
            }
            .padding()
        }
        .background(ScreenBackground(tint: Color(hex: 0x5B3CC4)))
        .navigationTitle("睡眠")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hero

    private func hero(_ night: SleepNight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(RelativeDay.label(for: night.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "bed.double.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(durationText(night.timeAsleep))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("睡眠时间")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                Label(Self.timeFormatter.string(from: night.bedtime), systemImage: "moon.fill")
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Label(Self.timeFormatter.string(from: night.wakeTime), systemImage: "sunrise.fill")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.95))
        }
        .gradientCardStyle([Color(hex: 0x9D7BFF), Color(hex: 0x5B3CC4)])
    }

    // MARK: Hypnogram (stage-over-time chart)

    private struct Bar: Identifiable {
        let id = UUID()
        let stage: SleepStage
        let start: Date
        let end: Date
    }

    private func hypnogramSegments(_ night: SleepNight) -> [Bar] {
        night.segments
            .filter { $0.stage != .unspecified || !night.hasStages }
            .map { Bar(stage: SleepStage.from($0.stage), start: $0.start, end: $0.end) }
    }

    private func hypnogramCard(_ night: SleepNight) -> some View {
        let bars = hypnogramSegments(night)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "睡眠阶段", systemImage: "waveform.path.ecg")
            Chart(bars) { bar in
                BarMark(
                    xStart: .value("开始", bar.start),
                    xEnd: .value("结束", bar.end),
                    y: .value("阶段", bar.stage.name),
                    height: .fixed(16)
                )
                .foregroundStyle(bar.stage.color)
                .cornerRadius(5)
            }
            .chartYScale(domain: SleepStage.axisOrder)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                }
            }
            .frame(height: 168)
        }
        .cardStyle()
    }

    // MARK: Stage chips

    private func stageChips(_ night: SleepNight) -> some View {
        let total = max(night.timeAsleep + night.awake, 1)
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach([SleepStage.core, .deep, .rem, .awake], id: \.self) { stage in
                let d = stage.duration(in: night)
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(stage.color)
                        .frame(width: 5, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(durationText(d))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    Spacer(minLength: 0)
                    Text("\(Int((d / total * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(stage.color)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: Stat strip

    private func statStrip(_ night: SleepNight) -> some View {
        HStack(spacing: 0) {
            statItem("在床时间", durationText(night.inBed))
            Divider().frame(height: 34)
            statItem("睡眠效率", "\(Int((night.efficiency * 100).rounded()))%")
            Divider().frame(height: 34)
            statItem("清醒", durationText(night.awake))
        }
        .cardStyle()
    }

    private func statItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Duration trend (week / month / quarter)

    /// Daily sleep-duration samples (hours) limited to the selected window.
    private var trendSamples: [DailySample] {
        guard let samples = durationSeries?.samples, let last = samples.last?.date else { return [] }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: last) else { return samples }
        return samples.filter { $0.date >= cutoff }
    }

    private var trendAverage: Double? {
        let values = trendSamples.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "睡眠时长趋势", systemImage: "chart.xyaxis.line")

            Picker("时间范围", selection: $range.animation(.easeInOut)) {
                ForEach(TrendRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            let samples = trendSamples
            if samples.count >= 2 {
                Chart {
                    if let avg = trendAverage {
                        RuleMark(y: .value("平均", avg))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(String(format: "平均 %.1f 小时", avg))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    ForEach(samples, id: \.date) { sample in
                        AreaMark(x: .value("日期", sample.date), y: .value("小时", sample.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0x9D7BFF).opacity(0.30), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("日期", sample.date), y: .value("小时", sample.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0x9D7BFF), Color(hex: 0x5B3CC4)], startPoint: .leading, endPoint: .trailing))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    if let last = samples.last {
                        PointMark(x: .value("日期", last.date), y: .value("小时", last.value))
                            .foregroundStyle(Color(hex: 0x5B3CC4))
                            .symbolSize(70)
                    }
                }
                .frame(height: 180)
                .chartYAxisLabel("小时")
            } else {
                Label("该范围内的睡眠数据还不足以绘制趋势。", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .cardStyle()
    }

    // MARK: Formatting

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分" }
        return "\(m)分"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
}
