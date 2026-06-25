import Foundation

#if canImport(HealthKit) && (os(iOS) || os(watchOS))
import HealthKit

/// Thin adapter between HealthKit and the platform-agnostic models/analytics
/// in this package. Every method here returns `MetricTimeSeries`/
/// `WorkoutSummary` so the analytics engine never has to know HealthKit
/// exists. This file is compiled out entirely on platforms without
/// HealthKit (e.g. when the core package is unit-tested on macOS).
public final class HealthKitManager: @unchecked Sendable {
    public static let shared = HealthKitManager()

    private let store = HKHealthStore()

    public enum HealthKitManagerError: Error {
        case notAvailableOnThisDevice
    }

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN, .restingHeartRate, .respiratoryRate,
            .oxygenSaturation, .vo2Max, .bodyMass, .heartRate
        ]
        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private let shareTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        return types
    }()

    public init() {}

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitManagerError.notAvailableOnThisDevice
        }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Daily quantity series

    private func dailySamples(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        aggregation: HKStatisticsOptions,
        days: Int,
        endingAt referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> [DailySample] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let startDate = calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        let anchorDate = calendar.startOfDay(for: startDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: nil,
                options: aggregation,
                anchorDate: anchorDate,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var samples: [DailySample] = []
                results?.enumerateStatistics(from: startDate, to: referenceDate) { stats, _ in
                    let value: Double?
                    if aggregation.contains(.cumulativeSum) {
                        value = stats.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        value = stats.averageQuantity()?.doubleValue(for: unit)
                    }
                    if let value {
                        samples.append(DailySample(date: stats.startDate, value: value))
                    }
                }
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
    }

    public func fetchHRV(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .heartRateVariability, samples: samples)
    }

    public func fetchRestingHeartRate(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .restingHeartRate, samples: samples)
    }

    public func fetchRespiratoryRate(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .respiratoryRate, samples: samples)
    }

    public func fetchOxygenSaturation(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .oxygenSaturation, unit: .percent(), aggregation: .discreteAverage, days: days)
        let asPercentage = samples.map { DailySample(date: $0.date, value: $0.value * 100) }
        return MetricTimeSeries(metric: .oxygenSaturation, samples: asPercentage)
    }

    public func fetchVO2Max(days: Int = 180) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .vo2Max, unit: HKUnit(from: "ml/(kg*min)"), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .vo2Max, samples: samples)
    }

    public func fetchBodyMass(days: Int = 180) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .bodyMass, unit: .gramUnit(with: .kilo), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .bodyMass, samples: samples)
    }

    public func saveBodyMass(kilograms: Double, date: Date = Date()) async throws {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    // MARK: - Sleep

    /// Sleep duration (hours asleep) and efficiency (asleep / in-bed), keyed
    /// by the calendar day the sleep session *ended* on, since most sleep
    /// spans midnight and should count toward the following morning.
    public func fetchSleep(days: Int = 60, calendar: Calendar = .current) async throws -> (duration: MetricTimeSeries, efficiency: MetricTimeSeries) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (MetricTimeSeries(metric: .sleepDuration, samples: []), MetricTimeSeries(metric: .sleepEfficiency, samples: []))
        }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let categorySamples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        var asleepSecondsByNight: [Date: Double] = [:]
        var inBedSecondsByNight: [Date: Double] = [:]

        for sample in categorySamples {
            let night = calendar.startOfDay(for: sample.endDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed:
                inBedSecondsByNight[night, default: 0] += duration
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                asleepSecondsByNight[night, default: 0] += duration
                inBedSecondsByNight[night, default: 0] += duration
            default:
                break
            }
        }

        let durationSamples = asleepSecondsByNight.map { DailySample(date: $0.key, value: $0.value / 3600.0) }
        let efficiencySamples = asleepSecondsByNight.compactMap { night, asleepSeconds -> DailySample? in
            guard let inBedSeconds = inBedSecondsByNight[night], inBedSeconds > 0 else { return nil }
            return DailySample(date: night, value: min(100, asleepSeconds / inBedSeconds * 100))
        }

        return (
            MetricTimeSeries(metric: .sleepDuration, samples: durationSamples),
            MetricTimeSeries(metric: .sleepEfficiency, samples: efficiencySamples)
        )
    }

    // MARK: - Workouts (for TRIMP / training load)

    public func fetchWorkouts(days: Int = 35, calendar: Calendar = .current) async throws -> [WorkoutSummary] {
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var summaries: [WorkoutSummary] = []
        for workout in workouts {
            let avgHR = try? await averageHeartRate(forWorkout: workout)
            summaries.append(
                WorkoutSummary(
                    startDate: workout.startDate,
                    durationMinutes: workout.duration / 60.0,
                    averageHeartRate: avgHR,
                    activityName: workout.workoutActivityType.displayName
                )
            )
        }
        return summaries
    }

    private func averageHeartRate(forWorkout workout: HKWorkout) async throws -> Double? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        let predicate = HKQuery.predicateForObjects(from: workout)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Convenience aggregate fetch

    /// Fetches every tracked metric concurrently. The single call a
    /// dashboard view model needs to refresh all trend data at once.
    public func fetchAllMetricSeries(days: Int = 60) async throws -> [MetricTimeSeries] {
        async let hrv = fetchHRV(days: days)
        async let rhr = fetchRestingHeartRate(days: days)
        async let respiratory = fetchRespiratoryRate(days: days)
        async let oxygen = fetchOxygenSaturation(days: days)
        async let vo2Max = fetchVO2Max(days: max(days, 180))
        async let bodyMass = fetchBodyMass(days: max(days, 180))
        async let sleep = fetchSleep(days: days)

        let sleepResult = try await sleep
        return [
            try await hrv, try await rhr, try await respiratory, try await oxygen,
            try await vo2Max, try await bodyMass, sleepResult.duration, sleepResult.efficiency
        ]
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "跑步"
        case .cycling: return "骑行"
        case .walking: return "步行"
        case .swimming: return "游泳"
        case .yoga: return "瑜伽"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "力量训练"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "椭圆机"
        case .rowing: return "划船"
        case .hiking: return "徒步"
        default: return "锻炼"
        }
    }
}

#endif
