import Foundation

/// A single day's aggregated value for a metric (e.g. mean overnight HRV).
public struct DailySample: Codable, Hashable, Sendable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// A timeseries of daily samples for one metric, sorted ascending by date.
public struct MetricTimeSeries: Sendable {
    public let metric: MetricType
    public let samples: [DailySample]

    public init(metric: MetricType, samples: [DailySample]) {
        self.metric = metric
        self.samples = samples.sorted { $0.date < $1.date }
    }

    /// Samples within `days` of `referenceDate`, inclusive, ascending order.
    public func trailing(days: Int, before referenceDate: Date, calendar: Calendar = .current) -> [DailySample] {
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: referenceDate) else { return [] }
        return samples.filter { $0.date > cutoff && $0.date <= referenceDate }
    }

    public func value(on date: Date, calendar: Calendar = .current) -> Double? {
        samples.first { calendar.isDate($0.date, inSameDayAs: date) }?.value
    }

    /// The most recent sample at or before `referenceDate` that is no more
    /// than `maxAgeDays` old. Used to surface a "current" reading even when
    /// today's value hasn't been recorded yet (the common case for overnight
    /// metrics). `samples` is sorted ascending, so `.last` is the newest match.
    public func mostRecentSample(asOf referenceDate: Date, maxAgeDays: Int, calendar: Calendar = .current) -> DailySample? {
        guard let cutoff = calendar.date(byAdding: .day, value: -maxAgeDays, to: referenceDate) else { return nil }
        let earliest = calendar.startOfDay(for: cutoff)
        return samples.last { $0.date >= earliest && $0.date <= referenceDate }
    }
}

/// Today's everyday-activity totals for the home-screen summary.
public struct ActivitySummary: Codable, Hashable, Sendable {
    public let date: Date
    public let steps: Double
    public let activeEnergyKilocalories: Double
    public let exerciseMinutes: Double

    public init(date: Date, steps: Double, activeEnergyKilocalories: Double, exerciseMinutes: Double) {
        self.date = date
        self.steps = steps
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
    }

    /// True when at least one source reported movement today — lets the UI hide
    /// the card before any data has synced rather than showing all zeros.
    public var hasData: Bool {
        steps > 0 || activeEnergyKilocalories > 0 || exerciseMinutes > 0
    }
}

/// A sleep stage, used both for per-segment timeline (hypnogram) and totals.
public enum SleepStageKind: String, Codable, Sendable, CaseIterable {
    case awake, rem, core, deep, unspecified
}

/// One continuous stretch of a single sleep stage — the data behind a
/// hypnogram (the stepped stage-over-time chart in Apple Health).
public struct SleepSegment: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let stage: SleepStageKind
    public let start: Date
    public let end: Date

    public init(id: UUID = UUID(), stage: SleepStageKind, start: Date, end: Date) {
        self.id = id
        self.stage = stage
        self.start = start
        self.end = end
    }
}

/// One night's sleep, broken down by stage — the data behind a native-Health-
/// style sleep detail (bedtime, wake time, core/deep/REM/awake durations).
public struct SleepNight: Codable, Hashable, Sendable, Identifiable {
    /// Calendar day the session ended on (the morning you woke up).
    public let date: Date
    public let bedtime: Date
    public let wakeTime: Date
    public let inBed: TimeInterval
    public let core: TimeInterval
    public let deep: TimeInterval
    public let rem: TimeInterval
    public let awake: TimeInterval
    /// "Asleep" samples with no stage (older devices / 3rd-party sources).
    public let unspecified: TimeInterval
    /// Per-stage timeline for the night, ascending by start — drives the hypnogram.
    public let segments: [SleepSegment]

    public var id: Date { date }

    public init(date: Date, bedtime: Date, wakeTime: Date, inBed: TimeInterval, core: TimeInterval, deep: TimeInterval, rem: TimeInterval, awake: TimeInterval, unspecified: TimeInterval, segments: [SleepSegment] = []) {
        self.date = date
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.inBed = inBed
        self.core = core
        self.deep = deep
        self.rem = rem
        self.awake = awake
        self.unspecified = unspecified
        self.segments = segments
    }

    /// Total time actually asleep (all asleep stages combined).
    public var timeAsleep: TimeInterval { core + deep + rem + unspecified }

    /// Whether per-stage data exists (vs. only a flat "asleep" total).
    public var hasStages: Bool { core + deep + rem > 0 }

    /// Asleep / in-bed, clamped to 0...1. Falls back to 1 when no in-bed record.
    public var efficiency: Double {
        let denom = max(inBed, timeAsleep)
        return denom > 0 ? min(1, timeAsleep / denom) : 1
    }
}

/// Workout summary used as input to training-load calculations.
public struct WorkoutSummary: Codable, Hashable, Sendable {
    public let startDate: Date
    public let durationMinutes: Double
    public let averageHeartRate: Double?
    public let activityName: String
    /// Fallback intensity (fraction of heart-rate reserve, 0...1) inferred from
    /// the workout *type* when no heart-rate samples were recorded — lets
    /// manually-logged or third-party workouts still contribute training load.
    public let estimatedIntensityFraction: Double?

    public init(startDate: Date, durationMinutes: Double, averageHeartRate: Double?, activityName: String, estimatedIntensityFraction: Double? = nil) {
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.averageHeartRate = averageHeartRate
        self.activityName = activityName
        self.estimatedIntensityFraction = estimatedIntensityFraction
    }

    public var isSupplementalWalking: Bool {
        activityName == "日常步行"
    }
}
