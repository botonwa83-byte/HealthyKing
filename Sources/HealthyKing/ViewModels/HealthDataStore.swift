import Foundation
import HealthyKingKit

/// Single source of truth for the app: owns the HealthKit fetch, runs every
/// metric through the InsightEngine, computes the composite recovery score
/// and training-load assessment, and publishes the results for both the
/// iOS dashboard and (via the same package) the watch app.
@MainActor
final class HealthDataStore: ObservableObject {
    @Published private(set) var metricSeries: [MetricType: MetricTimeSeries] = [:]
    @Published private(set) var insights: [MetricType: MetricInsight] = [:]
    @Published private(set) var recovery: RecoveryScoreResult?
    @Published private(set) var trainingLoad: TrainingLoadResult?
    @Published private(set) var acwrHistory: [DailySample] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var hasLoadedOnce = false

    private let healthKit = HealthKitManager.shared
    private let insightEngine = InsightEngine()
    private let recoveryEngine = RecoveryScoreEngine()
    private let acwrCalculator = ACWRCalculator()

    /// Basic profile, used only to personalize the TRIMP heart-rate-reserve
    /// calculation -- never transmitted anywhere.
    var age: Int = 30
    var biologicalSex: BiologicalSexInput = .unspecified

    func requestAuthorizationAndLoad() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await healthKit.requestAuthorization()
            await refresh()
        } catch {
            lastError = "无法连接健康App：\(error.localizedDescription)"
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let seriesList = try await healthKit.fetchAllMetricSeries(days: 60)
            metricSeries = Dictionary(uniqueKeysWithValues: seriesList.map { ($0.metric, $0) })

            let today = Date()
            insights = insightEngine.insights(for: seriesList, asOf: today)
            recovery = recoveryEngine.score(from: insights)
            trainingLoad = try await computeTrainingLoad(asOf: today)
            hasLoadedOnce = true
            lastError = nil
        } catch {
            lastError = "数据加载失败：\(error.localizedDescription)"
        }
    }

    private func computeTrainingLoad(asOf referenceDate: Date) async throws -> TrainingLoadResult {
        let workouts = try await healthKit.fetchWorkouts(days: 63)
        let restingHR = metricSeries[.restingHeartRate]?.samples.last?.value ?? 60
        let maxHR = TRIMPCalculator.estimatedMaxHeartRate(age: age)
        let trimpCalculator = TRIMPCalculator(restingHeartRate: restingHR, maxHeartRate: maxHR, sex: biologicalSex)
        let dailyLoad = trimpCalculator.dailyLoad(forWorkouts: workouts)

        let calendar = Calendar.current
        var history: [DailySample] = []
        for offset in stride(from: 29, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDate) else { continue }
            let result = acwrCalculator.evaluate(dailyLoad: dailyLoad, asOf: day, calendar: calendar)
            if let acwr = result.acwr, result.isReliable {
                history.append(DailySample(date: day, value: acwr))
            }
        }
        acwrHistory = history

        return acwrCalculator.evaluate(dailyLoad: dailyLoad, asOf: referenceDate, calendar: calendar)
    }
}
