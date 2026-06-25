import SwiftUI
import HealthyKingKit

struct RecoveryComponentRow: View {
    let component: RecoveryComponent

    private var barFraction: Double {
        max(-1, min(1, component.contributionPoints / 20.0))
    }

    private var barColor: Color {
        barFraction >= 0 ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: component.metric.symbolName)
                .font(.subheadline)
                .foregroundStyle(component.metric.tintColor)
                .frame(width: 28, height: 28)
                .background(component.metric.tintColor.opacity(0.15), in: Circle())

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
            GeometryReader { proxy in
                ZStack(alignment: barFraction >= 0 ? .leading : .trailing) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(barColor.gradient)
                        .frame(width: proxy.size.width * abs(barFraction) / 2)
                        .offset(x: barFraction >= 0 ? proxy.size.width / 2 : -proxy.size.width / 2)
                }
            }
            .frame(width: 70, height: 8)
        }
        .padding(.vertical, 2)
    }
}
