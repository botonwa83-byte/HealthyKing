import SwiftUI
import HealthyKingKit

/// A metric's standing relative to the user's own rolling baseline, expressed
/// as a colored status so health state reads at a glance. Shared across the
/// dashboard and the trends/insights screens.
enum MetricStatus {
    case excellent, normal, slightlyOff, watch, calibrating

    static func evaluate(_ insight: MetricInsight?) -> MetricStatus {
        guard let z = insight?.zScore?.directed else { return .calibrating }
        if z >= 1.0 { return .excellent }
        if z >= -0.6 { return .normal }
        if z >= -1.5 { return .slightlyOff }
        return .watch
    }

    var label: String {
        switch self {
        case .excellent: return "优秀"
        case .normal: return "正常"
        case .slightlyOff: return "略偏离"
        case .watch: return "需关注"
        case .calibrating: return "校准中"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(hex: 0x16A34A)
        case .normal: return Color(hex: 0x2563EB)
        case .slightlyOff: return Color(hex: 0xF59E0B)
        case .watch: return Color(hex: 0xE0102A)
        case .calibrating: return .secondary
        }
    }
}

struct StatusPill: View {
    let status: MetricStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.14), in: Capsule())
    }
}

/// Relative-day label for a recorded date ("今天 / 昨天 / 前天 / N天前 / N周前").
enum RelativeDay {
    static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<0: return "今天"
        case 0: return "今天"
        case 1: return "昨天"
        case 2: return "前天"
        case 3...6: return "\(days)天前"
        default: return "\(days / 7)周前"
        }
    }
}

/// Gentler-Streak-style "health metric" bar: a track with the user's personal
/// normal band highlighted and a marker showing where the current reading sits.
/// Communicates "within / above / below your normal range" at a glance.
struct MetricRangeBar: View {
    let metric: MetricType
    let value: Double
    let baseline: BaselineStats
    let status: MetricStatus

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let sd = max(baseline.standardDeviation, abs(baseline.mean) * 0.02, 0.1)
            let lo = min(value, baseline.mean - 2.4 * sd)
            let hi = max(value, baseline.mean + 2.4 * sd)
            let span = max(hi - lo, 0.0001)

            let normalLo = (baseline.normalRange.lowerBound - lo) / span
            let normalHi = (baseline.normalRange.upperBound - lo) / span
            let valueFrac = (value - lo) / span

            let trackHeight: CGFloat = 7
            let markerSize: CGFloat = 13

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: trackHeight)

                Capsule()
                    .fill((metric.gradientColors.last ?? Brand.primary).opacity(0.28))
                    .frame(width: max(width * (normalHi - normalLo), 4), height: trackHeight)
                    .offset(x: width * normalLo)

                Circle()
                    .fill(status.color)
                    .frame(width: markerSize, height: markerSize)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: min(max(width * valueFrac - markerSize / 2, 0), width - markerSize))
            }
            .frame(height: markerSize)
        }
        .frame(height: 13)
    }
}
