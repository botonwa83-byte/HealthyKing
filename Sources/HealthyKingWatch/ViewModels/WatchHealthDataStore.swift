import Foundation
import HealthyKingKit

/// Lightweight counterpart to the iOS app's HealthDataStore, scoped to what
/// the small watch UI actually shows: today's recovery score, a handful of
/// trend arrows, and the current training-load zone. The watch fetches
/// HealthKit data independently (HealthKit is available standalone on
/// watchOS) so this view works even when the iPhone isn't nearby.
@MainActor
final class WatchHealthDataStore: ObservableObject {
    @Published private(set) var insights: [MetricType: MetricInsight] = [:]
    @Published private(set) var recovery: RecoveryScoreResult?
    @Published private(set) var trainingLoad: TrainingLoadResult?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let healthKit = HealthKitManager.shared
    private let insightEngine = InsightEngine()
    private let recoveryEngine = RecoveryScoreEngine()
    private let acwrCalculator = ACWRCalculator()

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await healthKit.requestAuthorization()
            let seriesList = try await healthKit.fetchAllMetricSeries(days: 35)
            let today = Date()
            insights = insightEngine.insights(for: seriesList, asOf: today)
            recovery = recoveryEngine.score(from: insights)

            let workouts = try await healthKit.fetchWorkouts(days: 35)
            let restingHR = insights[.restingHeartRate]?.today ?? 60
            let trimpCalculator = TRIMPCalculator(
                restingHeartRate: restingHR,
                maxHeartRate: TRIMPCalculator.estimatedMaxHeartRate(age: 30),
                sex: .unspecified
            )
            let dailyLoad = trimpCalculator.dailyLoad(forWorkouts: workouts)
            trainingLoad = acwrCalculator.evaluate(dailyLoad: dailyLoad, asOf: today)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
