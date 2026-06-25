import SwiftUI
import HealthyKingKit

struct RecoveryComponentRow: View {
    let component: RecoveryComponent

    private var barFraction: Double {
        max(-1, min(1, component.contributionPoints / 20.0))
    }

    private var barColors: [Color] {
        barFraction >= 0 ? [Color(hex: 0x34E0A1), Color(hex: 0x16A34A)] : [Color(hex: 0xFFB347), Color(hex: 0xFF8008)]
    }

    var body: some View {
        HStack(spacing: 12) {
            GradientIconChip(systemName: component.metric.symbolName, colors: component.metric.gradientColors, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.metric.displayName)
                    .font(.subheadline)
                if let z = component.zScore {
                    Text(String(format: "较基线 %+.1f SD", z.directed))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("基线校准中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            if component.zScore != nil {
                Text(String(format: "%+.0f", component.contributionPoints.rounded()))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(barColors.last ?? .primary)
                    .frame(width: 30, alignment: .trailing)
            }

            GeometryReader { proxy in
                ZStack(alignment: barFraction >= 0 ? .leading : .trailing) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: barColors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * abs(barFraction) / 2)
                        .offset(x: barFraction >= 0 ? proxy.size.width / 2 : -proxy.size.width / 2)
                }
            }
            .frame(width: 64, height: 8)
        }
        .padding(.vertical, 2)
    }
}
