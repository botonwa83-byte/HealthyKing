import SwiftUI
import HealthyKingKit

/// Reusable recovery-score ring, shared between the Today list and the
/// recovery detail screen. Sizing is driven by `lineWidth` so the same view
/// works both as a small inline glyph and as a large hero ring.
struct RecoveryRing: View {
    let score: Int?
    let band: RecoveryBand?
    var lineWidth: CGFloat = 9
    var showsBandText: Bool = true

    private var ringColors: [Color] {
        switch band {
        case .needsRest: return [.orange, .red]
        case .moderate: return [.yellow, .orange]
        case .primed: return [.mint, .green]
        case nil: return [.gray.opacity(0.4), .gray.opacity(0.4)]
        }
    }

    private var bandColor: Color {
        switch band {
        case .needsRest: return .orange
        case .moderate: return .yellow
        case .primed: return .green
        case nil: return .secondary
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            if let score {
                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(
                        AngularGradient(colors: ringColors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: score)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: lineWidth * 3, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                    if showsBandText, let band {
                        Text(band.rawValue)
                            .font(.caption2)
                            .foregroundStyle(bandColor)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
}
