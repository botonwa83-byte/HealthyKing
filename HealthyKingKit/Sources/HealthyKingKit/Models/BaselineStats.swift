import Foundation

/// Rolling personal-baseline statistics for one metric, computed over a
/// trailing window. This is the reference point every "today" value is
/// compared against — never a population norm.
public struct BaselineStats: Sendable {
    public let metric: MetricType
    public let mean: Double
    public let standardDeviation: Double
    public let ewma: Double
    public let sampleCount: Int
    public let windowDays: Int

    /// Minimum number of days of history required before a baseline is
    /// considered statistically meaningful. Below this, the UI should show
    /// "still calibrating" rather than a confident comparison.
    public static let minimumSamplesForReliability = 14

    public var isReliable: Bool { sampleCount >= Self.minimumSamplesForReliability }

    public init(metric: MetricType, mean: Double, standardDeviation: Double, ewma: Double, sampleCount: Int, windowDays: Int) {
        self.metric = metric
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.ewma = ewma
        self.sampleCount = sampleCount
        self.windowDays = windowDays
    }

    /// Normal range band (±1 SD) used to shade charts.
    public var normalRange: ClosedRange<Double> {
        guard mean - standardDeviation <= mean + standardDeviation else { return mean...mean }
        return (mean - standardDeviation)...(mean + standardDeviation)
    }
}

/// Signed z-score of a value against a baseline, oriented so that positive
/// always means "trending toward better recovery" regardless of whether the
/// underlying metric is higher-is-better or lower-is-better.
public struct DirectedZScore: Sendable {
    public let raw: Double
    public let directed: Double

    public init(raw: Double, higherIsBetter: Bool) {
        self.raw = raw
        self.directed = higherIsBetter ? raw : -raw
    }
}

/// Result of change-point detection over a metric's recent history.
public enum ChangePointSignal: Equatable, Sendable {
    case none
    case shiftedUp(magnitudeInSD: Double)
    case shiftedDown(magnitudeInSD: Double)
}

/// Direction of a short-horizon statistical forecast.
public enum TrendDirection: String, Sendable {
    case rising
    case falling
    case stable
}

/// Output of the short-horizon linear trend forecaster.
public struct ForecastResult: Sendable {
    public let horizonDays: Int
    public let projectedValue: Double
    public let confidenceInterval: ClosedRange<Double>
    public let direction: TrendDirection
    public let slopePerDay: Double
}

/// Full per-metric insight bundle: today's value, baseline, z-score,
/// change-point signal, and forward-looking forecast.
public struct MetricInsight: Sendable {
    public let metric: MetricType
    public let today: Double?
    public let baseline: BaselineStats
    public let zScore: DirectedZScore?
    public let changePoint: ChangePointSignal
    public let forecast: ForecastResult?
}
