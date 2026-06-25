import Foundation

/// Computes personal rolling baselines: trailing-window mean/SD plus an
/// EWMA smoothed value. This is the statistical foundation every other
/// signal (z-score, change-point, forecast) is built on.
public struct RollingBaselineCalculator: Sendable {
    /// Smoothing factor for the EWMA. Higher = more weight on recent days.
    public let ewmaAlpha: Double
    public let windowDays: Int

    public init(windowDays: Int = 30, ewmaAlpha: Double = 0.2) {
        self.windowDays = windowDays
        self.ewmaAlpha = ewmaAlpha
    }

    public func baseline(for series: MetricTimeSeries, asOf referenceDate: Date, calendar: Calendar = .current) -> BaselineStats {
        let window = series.trailing(days: windowDays, before: referenceDate, calendar: calendar)
        let values = window.map(\.value)
        let mean = Self.mean(values)
        let sd = Self.standardDeviation(values, mean: mean)
        let ewma = Self.ewma(values, alpha: ewmaAlpha)
        return BaselineStats(
            metric: series.metric,
            mean: mean,
            standardDeviation: sd,
            ewma: ewma,
            sampleCount: values.count,
            windowDays: windowDays
        )
    }

    public func zScore(today: Double, baseline: BaselineStats) -> DirectedZScore? {
        guard baseline.isReliable, baseline.standardDeviation > 0 else { return nil }
        let raw = (today - baseline.mean) / baseline.standardDeviation
        return DirectedZScore(raw: raw, higherIsBetter: baseline.metric.higherIsBetter)
    }

    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }

    /// Exponentially weighted moving average, oldest-to-newest.
    static func ewma(_ values: [Double], alpha: Double) -> Double {
        guard let first = values.first else { return 0 }
        var current = first
        for value in values.dropFirst() {
            current = alpha * value + (1 - alpha) * current
        }
        return current
    }
}
