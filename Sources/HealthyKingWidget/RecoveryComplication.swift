import WidgetKit
import SwiftUI
import HealthyKingKit

struct RecoveryEntry: TimelineEntry {
    let date: Date
    let score: Int?
    let band: RecoveryBand?
}

struct RecoveryProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecoveryEntry {
        RecoveryEntry(date: Date(), score: 72, band: .moderate)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecoveryEntry) -> Void) {
        completion(RecoveryEntry(date: Date(), score: 72, band: .moderate))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecoveryEntry>) -> Void) {
        Task {
            let entry = await computeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    /// Deliberately does not call `requestAuthorization` -- a widget
    /// extension should never trigger a permission prompt itself. It only
    /// reads data the host app has already been authorized for during
    /// onboarding, falling back to a placeholder if that hasn't happened.
    private func computeEntry() async -> RecoveryEntry {
        do {
            let series = try await HealthKitManager.shared.fetchAllMetricSeries(days: 35)
            let insights = InsightEngine().insights(for: series, asOf: Date())
            let result = RecoveryScoreEngine().score(from: insights)
            return RecoveryEntry(date: Date(), score: result.score, band: result.band)
        } catch {
            return RecoveryEntry(date: Date(), score: nil, band: nil)
        }
    }
}

struct RecoveryComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecoveryEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(entry.score ?? 0), in: 0...100) {
                Text("恢复")
            } currentValueLabel: {
                Text(entry.score.map(String.init) ?? "--")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("恢复评分").font(.caption2)
                Text(entry.score.map(String.init) ?? "--").font(.title3.bold())
                if let band = entry.band {
                    Text(band.rawValue).font(.caption2)
                }
            }
        case .accessoryInline:
            Text("恢复 \(entry.score.map(String.init) ?? "--")")
        default:
            Text(entry.score.map(String.init) ?? "--")
        }
    }
}

struct RecoveryComplication: Widget {
    let kind = "RecoveryComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecoveryProvider()) { entry in
            RecoveryComplicationView(entry: entry)
        }
        .configurationDisplayName("恢复评分")
        .description("在表盘上查看你的恢复评分趋势")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
