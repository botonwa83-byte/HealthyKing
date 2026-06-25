import SwiftUI
import HealthyKingKit

struct RecoveryRingView: View {
    let result: RecoveryScoreResult?

    private var fraction: Double {
        guard let result else { return 0 }
        return Double(result.score) / 100.0
    }

    private var ringGradient: AngularGradient {
        let colors: [Color]
        switch result?.band {
        case .needsRest: colors = [.orange, .red]
        case .moderate: colors = [.yellow, .orange]
        case .primed: colors = [.mint, .green]
        case nil: colors = [.gray.opacity(0.4), .gray.opacity(0.4)]
        }
        return AngularGradient(colors: colors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }

    private var bandColor: Color {
        switch result?.band {
        case .needsRest: return .orange
        case .moderate: return .yellow
        case .primed: return .green
        case nil: return .secondary
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 16)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: bandColor.opacity(0.35), radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.7), value: fraction)

            VStack(spacing: 4) {
                if let result {
                    Text("\(result.score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(result.band.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(bandColor)
                    if !result.isReliable {
                        Label("基线校准中", systemImage: "hourglass")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .frame(width: 180, height: 180)
        .padding(.vertical, 8)
    }
}
