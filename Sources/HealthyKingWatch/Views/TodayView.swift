import SwiftUI
import HealthyKingKit

struct TodayView: View {
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var ringGradient: AngularGradient {
        let colors: [Color]
        switch dataStore.recovery?.band {
        case .needsRest: colors = [.orange, .red]
        case .moderate: colors = [.yellow, .orange]
        case .primed: colors = [.mint, .green]
        case nil: colors = [.gray.opacity(0.4), .gray.opacity(0.4)]
        }
        return AngularGradient(colors: colors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }

    private var bandColor: Color {
        switch dataStore.recovery?.band {
        case .needsRest: return .orange
        case .moderate: return .yellow
        case .primed: return .green
        case nil: return .secondary
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 9)
                    if let score = dataStore.recovery?.score {
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(ringGradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.6), value: score)
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            Text(dataStore.recovery?.band.rawValue ?? "")
                                .font(.caption2)
                                .foregroundStyle(bandColor)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 96, height: 96)
                .padding(.top, 4)

                if let trainingLoad = dataStore.trainingLoad, trainingLoad.isReliable {
                    Label(trainingLoad.zone.rawValue, systemImage: "figure.run")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }

                VStack(spacing: 6) {
                    ForEach(MetricType.recoveryComponents, id: \.self) { metric in
                        if let insight = dataStore.insights[metric], let today = insight.today {
                            HStack(spacing: 6) {
                                Image(systemName: metric.symbolName)
                                    .font(.caption2)
                                    .foregroundStyle(metric.tintColor)
                                    .frame(width: 16)
                                Text(shortName(metric))
                                    .font(.caption2)
                                Spacer()
                                Text(String(format: "%.0f", today))
                                    .font(.caption2.bold())
                                arrowIcon(for: insight)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 4)
        }
        .task { await dataStore.refresh() }
    }

    private func shortName(_ metric: MetricType) -> String {
        switch metric {
        case .heartRateVariability: return "HRV"
        case .restingHeartRate: return "静息心率"
        case .respiratoryRate: return "呼吸率"
        case .sleepEfficiency: return "睡眠效率"
        default: return metric.displayName
        }
    }

    @ViewBuilder
    private func arrowIcon(for insight: MetricInsight) -> some View {
        switch insight.changePoint {
        case .shiftedUp:
            Image(systemName: "arrow.up").font(.caption2).foregroundStyle(.blue)
        case .shiftedDown:
            Image(systemName: "arrow.down").font(.caption2).foregroundStyle(.orange)
        case .none:
            Image(systemName: "minus").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
