import SwiftUI
import HealthyKingKit

/// Hero recovery card: a vivid band-colored gradient panel with a white score
/// ring — the centerpiece of the dashboard.
struct RecoveryRingView: View {
    let result: RecoveryScoreResult?

    private var fraction: Double {
        guard let result else { return 0 }
        return Double(result.score) / 100.0
    }

    private var gradientColors: [Color] {
        result?.band.gradientColors ?? [Color(hex: 0x9AA0A6), Color(hex: 0x6B7177)]
    }

    var body: some View {
        HStack(spacing: 20) {
            ring
                .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 6) {
                Text("恢复评分")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(result?.band.rawValue ?? "—")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                if let result, !result.isReliable {
                    Label("基线校准中", systemImage: "hourglass")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                } else if let result {
                    Text(result.band.gentleMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("基于你的个人基线")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
        }
        .gradientCardStyle(gradientColors)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .white.opacity(0.5), radius: 6)
                .animation(.easeInOut(duration: 0.7), value: fraction)

            if let result {
                Text("\(result.score)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

private extension RecoveryBand {
    /// Kind, behavioral one-liner shown under the score — Gentler-Streak tone.
    var gentleMessage: String {
        switch self {
        case .needsRest: return "今天对自己温柔些，优先安排恢复。"
        case .moderate: return "状态平稳，按计划正常活动即可。"
        case .primed: return "身体已准备好，可以放心发力。"
        }
    }
}
