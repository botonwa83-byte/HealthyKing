import Foundation

/// Single entry point that wires together the baseline, change-point, and
/// forecasting primitives for one metric's history. UI and widget code
/// should go through this rather than calling the individual calculators
/// directly, so the analytical approach stays consistent everywhere it's
/// surfaced (dashboard, trend charts, complications).
public struct InsightEngine: Sendable {
    public let baselineCalculator: RollingBaselineCalculator
    public let changeDetector: CUSUMDetector
    public let forecaster: TrendForecaster

    public init(
        baselineCalculator: RollingBaselineCalculator = RollingBaselineCalculator(),
        changeDetector: CUSUMDetector = CUSUMDetector(),
        forecaster: TrendForecaster = TrendForecaster()
    ) {
        self.baselineCalculator = baselineCalculator
        self.changeDetector = changeDetector
        self.forecaster = forecaster
    }

    public func insight(for series: MetricTimeSeries, asOf referenceDate: Date, calendar: Calendar = .current) -> MetricInsight {
        // Baseline is computed over the window *ending the day before* the
        // recent window used for change detection, so a detector can't
        // "see" the very data it's trying to flag as anomalous.
        guard let priorReference = calendar.date(byAdding: .day, value: -7, to: referenceDate) else {
            let baseline = baselineCalculator.baseline(for: series, asOf: referenceDate, calendar: calendar)
            return MetricInsight(metric: series.metric, today: series.value(on: referenceDate, calendar: calendar), baseline: baseline, zScore: nil, changePoint: .none, forecast: nil)
        }

        let baseline = baselineCalculator.baseline(for: series, asOf: priorReference, calendar: calendar)
        let today = series.value(on: referenceDate, calendar: calendar)
        let zScore = today.flatMap { baselineCalculator.zScore(today: $0, baseline: baseline) }

        let recentWindow = series.trailing(days: 7, before: referenceDate, calendar: calendar).map(\.value)
        let changePoint = baseline.isReliable
            ? changeDetector.detect(values: recentWindow, baselineMean: baseline.mean, baselineSD: baseline.standardDeviation)
            : .none

        let forecast = forecaster.forecast(for: series, asOf: referenceDate, calendar: calendar)

        return MetricInsight(metric: series.metric, today: today, baseline: baseline, zScore: zScore, changePoint: changePoint, forecast: forecast)
    }

    public func insights(for seriesList: [MetricTimeSeries], asOf referenceDate: Date, calendar: Calendar = .current) -> [MetricType: MetricInsight] {
        Dictionary(uniqueKeysWithValues: seriesList.map { ($0.metric, insight(for: $0, asOf: referenceDate, calendar: calendar)) })
    }
}
