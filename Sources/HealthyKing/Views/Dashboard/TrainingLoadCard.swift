import SwiftUI
import HealthyKingKit

struct TrainingLoadCard: View {
    let result: TrainingLoadResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "训练负荷", systemImage: "figure.run")

            if let result, result.isReliable, let acwr = result.acwr {
                HStack {
                    Label(result.zone.rawValue, systemImage: zoneIcon(for: result.zone))
                        .font(.subheadline.bold())
                        .foregroundStyle(color(for: result.zone))
                    Spacer()
                    Text(String(format: "ACWR %.2f", acwr))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
                Text(result.zone.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(.secondary)
                    Text("训练数据积累中，再坚持几次记录的锻炼后即可生成负荷评估。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private func color(for zone: TrainingLoadZone) -> Color {
        switch zone {
        case .detraining: return .blue
        case .optimal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }

    private func zoneIcon(for zone: TrainingLoadZone) -> String {
        switch zone {
        case .detraining: return "arrow.down.circle.fill"
        case .optimal: return "checkmark.circle.fill"
        case .elevated: return "exclamationmark.triangle.fill"
        case .high: return "flame.fill"
        }
    }
}
