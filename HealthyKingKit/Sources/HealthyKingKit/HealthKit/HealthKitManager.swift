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
            .oxygenSaturation, .vo2Max, .bodyMass, .heartRate,
            // Everyday activity, shown as today's summary on the home screen and
            // fed into training load even without a formal workout.
            .stepCount, .activeEnergyBurned, .appleExerciseTime
        ]
        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        // Characteristics used to individualize training-load math (max HR
        // from age, TRIMP sex constant) instead of hard-coding age 30.
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dob)
        }
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(sex)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    public init() {}

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitManagerError.notAvailableOnThisDevice
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - User characteristics

    /// Age (years) and biological sex read from the Health profile, used to
    /// individualize the training-load math. Either field may be nil/unspecified
    /// if the user hasn't filled it in or hasn't granted access.
    public struct BiologicalProfile: Sendable {
        public let age: Int?
        public let sex: BiologicalSexInput
        public init(age: Int?, sex: BiologicalSexInput) {
            self.age = age
            self.sex = sex
        }
    }

    public func biologicalProfile(calendar: Calendar = .current, now: Date = Date()) -> BiologicalProfile {
        var age: Int?
        if let components = try? store.dateOfBirthComponents(),
           let birthDate = calendar.date(from: components),
           let years = calendar.dateComponents([.year], from: birthDate, to: now).year,
           years > 0, years < 120 {
            age = years
        }

        var sex: BiologicalSexInput = .unspecified
        if let hkSex = try? store.biologicalSex().biologicalSex {
            switch hkSex {
            case .male: sex = .male
            case .female: sex = .female
            default: sex = .unspecified
            }
        }
        return BiologicalProfile(age: age, sex: sex)
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

    /// Averages quantity samples per night, counting only overnight readings
    /// (evening through late morning) and discarding daytime ones. HRV and
    /// respiratory rate are physiologically meaningful as *resting/overnight*
    /// values; a plain all-day average mixes in elevated daytime readings and
    /// won't match the morning numbers users see in the Health app.
    private func nightlyAverage(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int,
        eveningHour: Int = 21,
        morningHour: Int = 11,
        endingAt referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> [DailySample] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let start = calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        let predicate = HKQuery.predicateForSamples(withStart: start, end: referenceDate, options: .strictStartDate)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        var sumByNight: [Date: Double] = [:]
        var countByNight: [Date: Int] = [:]
        for sample in samples {
            let hour = calendar.component(.hour, from: sample.startDate)
            let dayStart = calendar.startOfDay(for: sample.startDate)
            let nightKey: Date?
            if hour < morningHour {
                nightKey = dayStart                                              // early-morning reading -> this morning
            } else if hour >= eveningHour {
                nightKey = calendar.date(byAdding: .day, value: 1, to: dayStart) // late-evening reading -> next morning
            } else {
                nightKey = nil                                                   // daytime -> ignore
            }
            guard let key = nightKey else { continue }
            sumByNight[key, default: 0] += sample.quantity.doubleValue(for: unit)
            countByNight[key, default: 0] += 1
        }

        return sumByNight.compactMap { key, sum -> DailySample? in
            guard let count = countByNight[key], count > 0 else { return nil }
            return DailySample(date: key, value: sum / Double(count))
        }
    }

    public func fetchHRV(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await nightlyAverage(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: days)
        return MetricTimeSeries(metric: .heartRateVariability, samples: samples)
    }

    public func fetchRestingHeartRate(days: Int = 60) async throws -> MetricTimeSeries {
        // Resting HR is already published by HealthKit as one curated value per
        // day, so a daily average is correct here (no overnight filtering needed).
        let samples = try await dailySamples(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .restingHeartRate, samples: samples)
    }

    public func fetchRespiratoryRate(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await nightlyAverage(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: days)
        return MetricTimeSeries(metric: .respiratoryRate, samples: samples)
    }

    public func fetchOxygenSaturation(days: Int = 60) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .oxygenSaturation, unit: .percent(), aggregation: .discreteAverage, days: days)
        let asPercentage = samples.map { DailySample(date: $0.date, value: $0.value * 100) }
        return MetricTimeSeries(metric: .oxygenSaturation, samples: asPercentage)
    }

    public func fetchVO2Max(days: Int = 365) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .vo2Max, unit: HKUnit(from: "ml/(kg*min)"), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .vo2Max, samples: samples)
    }

    public func fetchBodyMass(days: Int = 365) async throws -> MetricTimeSeries {
        let samples = try await dailySamples(for: .bodyMass, unit: .gramUnit(with: .kilo), aggregation: .discreteAverage, days: days)
        return MetricTimeSeries(metric: .bodyMass, samples: samples)
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
                // In-bed time comes only from inBed samples — asleep stages are
                // a *subset* of time in bed, so folding them into the in-bed
                // total (as before) double-counted it and deflated efficiency.
                inBedSecondsByNight[night, default: 0] += duration
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                asleepSecondsByNight[night, default: 0] += duration
            default:
                break
            }
        }

        let durationSamples = asleepSecondsByNight.map { DailySample(date: $0.key, value: $0.value / 3600.0) }
        let efficiencySamples = asleepSecondsByNight.compactMap { night, asleepSeconds -> DailySample? in
            // Prefer measured in-bed time; some sources only log asleep stages
            // with no inBed record, in which case the asleep extent is the best
            // available denominator (efficiency reads ~100%).
            let inBedSeconds = max(inBedSecondsByNight[night] ?? 0, asleepSeconds)
            guard inBedSeconds > 0 else { return nil }
            return DailySample(date: night, value: min(100, asleepSeconds / inBedSeconds * 100))
        }

        return (
            MetricTimeSeries(metric: .sleepDuration, samples: durationSamples),
            MetricTimeSeries(metric: .sleepEfficiency, samples: efficiencySamples)
        )
    }

    /// Per-night, stage-resolved sleep for the rich sleep detail view. Groups
    /// raw sleep-analysis samples by the morning they ended on and accumulates
    /// each stage's duration plus the bedtime/wake bounds.
    public func fetchSleepNights(days: Int = 30, calendar: Calendar = .current) async throws -> [SleepNight] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
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

        struct Accumulator {
            var inBed = 0.0, core = 0.0, deep = 0.0, rem = 0.0, awake = 0.0, unspecified = 0.0
            var bedtime: Date?
            var wake: Date?
            var segments: [SleepSegment] = []
        }
        var byNight: [Date: Accumulator] = [:]

        for sample in samples {
            let night = calendar.startOfDay(for: sample.endDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            var acc = byNight[night] ?? Accumulator()
            var isAsleep = false
            var stage: SleepStageKind?
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed: acc.inBed += duration
            case .awake: acc.awake += duration; stage = .awake
            case .asleepCore: acc.core += duration; isAsleep = true; stage = .core
            case .asleepDeep: acc.deep += duration; isAsleep = true; stage = .deep
            case .asleepREM: acc.rem += duration; isAsleep = true; stage = .rem
            case .asleepUnspecified: acc.unspecified += duration; isAsleep = true; stage = .unspecified
            default: break
            }
            if let stage {
                acc.segments.append(SleepSegment(stage: stage, start: sample.startDate, end: sample.endDate))
            }
            // Bedtime = earliest sample start; wake = latest asleep-sample end.
            if acc.bedtime == nil || sample.startDate < acc.bedtime! { acc.bedtime = sample.startDate }
            if isAsleep, acc.wake == nil || sample.endDate > acc.wake! { acc.wake = sample.endDate }
            byNight[night] = acc
        }

        return byNight.compactMap { night, acc -> SleepNight? in
            let asleep = acc.core + acc.deep + acc.rem + acc.unspecified
            guard asleep > 0 else { return nil }
            return SleepNight(
                date: night,
                bedtime: acc.bedtime ?? night,
                wakeTime: acc.wake ?? acc.bedtime ?? night,
                inBed: max(acc.inBed, asleep),
                core: acc.core, deep: acc.deep, rem: acc.rem,
                awake: acc.awake, unspecified: acc.unspecified,
                segments: acc.segments.sorted { $0.start < $1.start }
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Workouts (for TRIMP / training load)

    public func fetchWorkouts(days: Int = 365, calendar: Calendar = .current) async throws -> [WorkoutSummary] {
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
                    activityName: workout.workoutActivityType.displayName,
                    estimatedIntensityFraction: workout.workoutActivityType.estimatedIntensityFraction
                )
            )
        }
        return summaries
    }

    /// Synthesizes a daily "walking" session from step counts so that everyday
    /// activity (步行数据) contributes to training load even when the user never
    /// starts a formal workout. Duration is estimated from the day's step count
    /// at a typical walking cadence; intensity falls back to the walking
    /// activity constant since these steps carry no recorded heart rate.
    public func fetchDailyWalkingLoad(days: Int = 365, calendar: Calendar = .current) async throws -> [WorkoutSummary] {
        let steps = try await dailySamples(
            for: .stepCount, unit: .count(), aggregation: .cumulativeSum, days: days, calendar: calendar
        )
        let cadence = 110.0          // steps per minute, typical walking pace
        let minSteps = 1500.0        // ignore near-sedentary days
        let walkingIntensity = 0.40  // fraction of heart-rate reserve for easy walking
        return steps.compactMap { sample -> WorkoutSummary? in
            guard sample.value >= minSteps else { return nil }
            let minutes = sample.value / cadence
            // Anchor at midday so the synthetic session buckets onto its own day.
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: sample.date) ?? sample.date
            return WorkoutSummary(
                startDate: noon,
                durationMinutes: minutes,
                averageHeartRate: nil,
                activityName: "日常步行",
                estimatedIntensityFraction: walkingIntensity
            )
        }
    }

    /// Today's everyday-activity totals, surfaced as the home-screen activity
    /// summary (Gentler-Streak-style "today" numbers).
    public func fetchTodayActivity(calendar: Calendar = .current, now: Date = Date()) async throws -> ActivitySummary {
        let start = calendar.startOfDay(for: now)
        async let steps = sumToday(.stepCount, unit: .count(), start: start, end: now)
        async let energy = sumToday(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: now)
        async let exercise = sumToday(.appleExerciseTime, unit: .minute(), start: start, end: now)
        return ActivitySummary(
            date: start,
            steps: try await steps,
            activeEnergyKilocalories: try await energy,
            exerciseMinutes: try await exercise
        )
    }

    private func sumToday(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    /// Combined training-load inputs: logged workouts (健身记录/训练记录) plus
    /// step-derived everyday walking (步行数据) on days with no logged workout.
    /// This keeps training load rich and non-empty for users who rarely start a
    /// formal session, while avoiding double-counting on days that have one.
    public func fetchTrainingLoadWorkouts(days: Int = 365, calendar: Calendar = .current) async throws -> [WorkoutSummary] {
        async let workoutsTask = fetchWorkouts(days: days, calendar: calendar)
        async let walkingTask = fetchDailyWalkingLoad(days: days, calendar: calendar)
        let workouts = try await workoutsTask
        let walking = try await walkingTask

        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
        let supplementalWalking = walking.filter { !workoutDays.contains(calendar.startOfDay(for: $0.startDate)) }
        return (workouts + supplementalWalking).sorted { $0.startDate < $1.startDate }
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
    public func fetchAllMetricSeries(days: Int = 365) async throws -> [MetricTimeSeries] {
        async let hrv = fetchHRV(days: days)
        async let rhr = fetchRestingHeartRate(days: days)
        async let respiratory = fetchRespiratoryRate(days: days)
        async let oxygen = fetchOxygenSaturation(days: days)
        async let vo2Max = fetchVO2Max(days: max(days, 365))
        async let bodyMass = fetchBodyMass(days: max(days, 365))
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

    /// Rough fraction of heart-rate reserve a typical session of this type
    /// sustains, used only when no measured heart rate is available. Values are
    /// conservative midpoints from training-zone guidance, not precise figures.
    var estimatedIntensityFraction: Double {
        switch self {
        case .highIntensityIntervalTraining: return 0.85
        case .running: return 0.75
        case .swimming, .rowing: return 0.70
        case .cycling, .elliptical: return 0.65
        case .hiking: return 0.55
        case .functionalStrengthTraining, .traditionalStrengthTraining: return 0.50
        case .walking: return 0.40
        case .yoga: return 0.30
        default: return 0.55
        }
    }
}

#endif
