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

    private var latest: SleepNight? { nights.last }

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
                    if nights.count >= 2 {
                        trendCard
                    }
                } else {
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

    // MARK: Trend (stacked stages)

    private var trendCard: some View {
        let recent = Array(nights.suffix(14))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "近期睡眠", systemImage: "chart.bar.xaxis")
            Chart {
                ForEach(recent) { night in
                    ForEach([SleepStage.deep, .core, .rem], id: \.self) { stage in
                        BarMark(
                            x: .value("日期", night.date, unit: .day),
                            y: .value("小时", stage.duration(in: night) / 3600)
                        )
                        .foregroundStyle(stage.color)
                    }
                }
            }
            .frame(height: 170)
            .chartForegroundStyleScale([
                SleepStage.deep.name: SleepStage.deep.color,
                SleepStage.core.name: SleepStage.core.color,
                SleepStage.rem.name: SleepStage.rem.color
            ])
            .chartYAxisLabel("小时")
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
