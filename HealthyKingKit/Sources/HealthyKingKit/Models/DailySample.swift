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
}

/// Workout summary used as input to training-load calculations.
public struct WorkoutSummary: Codable, Hashable, Sendable {
    public let startDate: Date
    public let durationMinutes: Double
    public let averageHeartRate: Double?
    public let activityName: String

    public init(startDate: Date, durationMinutes: Double, averageHeartRate: Double?, activityName: String) {
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.averageHeartRate = averageHeartRate
        self.activityName = activityName
    }
}
