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
    @Published private(set) var seriesByMetric: [MetricType: MetricTimeSeries] = [:]
    @Published private(set) var recovery: RecoveryScoreResult?
    @Published private(set) var trainingLoad: TrainingLoadResult?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    /// True once we've completed (or failed) at least one load, so the UI can
    /// tell "first launch, still loading" apart from "loaded, no data".
    var hasLoadedOnce: Bool { lastUpdated != nil || lastError != nil }

    private let healthKit = HealthKitManager.shared
    private let insightEngine = InsightEngine()
    private let recoveryEngine = RecoveryScoreEngine()
    private let acwrCalculator = ACWRCalculator()

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await healthKit.requestAuthorization()
            let seriesList = try await healthKit.fetchAllMetricSeries(days: 365)
            let today = Date()
            seriesByMetric = Dictionary(uniqueKeysWithValues: seriesList.map { ($0.metric, $0) })
            insights = insightEngine.insights(for: seriesList, asOf: today)
            recovery = recoveryEngine.score(from: insights)

            let workouts = try await healthKit.fetchTrainingLoadWorkouts(days: 365)
            // Individualize training load from the Health profile rather than
            // assuming a 30-year-old: max HR from age, TRIMP weighting from sex.
            let profile = healthKit.biologicalProfile()
            let restingHR = insights[.restingHeartRate]?.today ?? 60
            let maxHeartRate = TRIMPCalculator.estimatedMaxHeartRate(age: profile.age ?? 30)
            let trimpCalculator = TRIMPCalculator(
                restingHeartRate: restingHR,
                maxHeartRate: maxHeartRate,
                sex: profile.sex
            )
            let dailyLoad = trimpCalculator.dailyLoad(forWorkouts: workouts)
            trainingLoad = acwrCalculator.evaluate(dailyLoad: dailyLoad, asOf: today)
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
