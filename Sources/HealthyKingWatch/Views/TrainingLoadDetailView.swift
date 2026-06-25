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
                    statRow(title: "急性负荷 (7天)", value: String(format: "%.0f", load.acuteLoad))
                    statRow(title: "慢性负荷 (28天)", value: String(format: "%.0f", load.chronicLoad))

                    Text(load.zone.recommendation)
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
