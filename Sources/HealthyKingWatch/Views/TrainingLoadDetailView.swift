import SwiftUI
import HealthyKingKit

/// Training-load detail: the acute:chronic workload ratio, its zone, and the
/// behavioral recommendation that the Today screen only hints at.
struct TrainingLoadDetailView: View {
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var load: TrainingLoadResult? { dataStore.trainingLoad }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let load, load.isReliable {
                    zoneHeader(load)

                    if let acwr = load.acwr {
                        statRow(title: "急慢性负荷比 (ACWR)", value: String(format: "%.2f", acwr))
                    }
                    statRow(title: "近7天日均负荷", value: String(format: "%.0f", load.evidence.recentDailyAverage))
                    statRow(title: "28天日均基线", value: String(format: "%.0f", load.evidence.chronicDailyAverage))
                    statRow(title: "近7天来源", value: load.evidence.recentCompositionText)

                    Text(load.watchExplanation)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ContentUnavailablePlaceholder(
                        title: "训练负荷校准中",
                        message: "需要更多锻炼记录才能算出可靠的负荷趋势。",
                        systemImage: "figure.run"
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("训练负荷")
    }

    private func zoneHeader(_ load: TrainingLoadResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            Text(load.zone.rawValue)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold().monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension TrainingLoadResult {
    var watchExplanation: String {
        switch zone {
        case .detraining:
            return "近7天负荷低于你的长期节奏。若状态正常，可以安排轻松活动逐步恢复。"
        case .optimal:
            return "近7天负荷接近28天基线，当前节奏比较稳定。"
        case .elevated:
            return "近7天负荷高于28天基线，今天适合控制强度。"
        case .high:
            return "近7天负荷明显高于28天基线，建议优先恢复。"
        }
    }
}

private extension TrainingLoadEvidence {
    var recentCompositionText: String {
        if recentFormalWorkoutCount > 0 && recentWalkingDays > 0 {
            return "\(recentFormalWorkoutCount)练+\(recentWalkingDays)步"
        }
        if recentFormalWorkoutCount > 0 {
            return "\(recentFormalWorkoutCount)次锻炼"
        }
        if recentWalkingDays > 0 {
            return "\(recentWalkingDays)天步行"
        }
        return "暂无"
    }
}

/// Small reusable empty-state used where watchOS lacks `ContentUnavailableView`
/// niceties in compact layouts.
struct ContentUnavailablePlaceholder: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.bold())
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
