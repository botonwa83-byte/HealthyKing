import Foundation

/// Short-horizon statistical forecaster. Fits ordinary least-squares
/// regression over the recent window and projects forward, with a
/// confidence interval derived from residual variance and a t-test on the
/// slope to decide whether the trend is statistically meaningful or just
/// noise. Deliberately simple/explainable (no opaque ML) so every number
/// can be justified to the user and to an App Review reading the source.
public struct TrendForecaster: Sendable {
    public let regressionWindowDays: Int
    public let horizonDays: Int
    /// Minimum |t-statistic| for the slope to be called "rising"/"falling"
    /// rather than "stable". ~2.0 corresponds to roughly p < 0.05 for
    /// reasonably sized samples.
    public let significanceTThreshold: Double

    public init(regressionWindowDays: Int = 14, horizonDays: Int = 3, significanceTThreshold: Double = 2.0) {
        self.regressionWindowDays = regressionWindowDays
        self.horizonDays = horizonDays
        self.significanceTThreshold = significanceTThreshold
    }

    public func forecast(for series: MetricTimeSeries, asOf referenceDate: Date, calendar: Calendar = .current) -> ForecastResult? {
        let window = series.trailing(days: regressionWindowDays, before: referenceDate, calendar: calendar)
        guard window.count >= 5 else { return nil }

        let dayZero = window.first!.date
        let xs = window.map { calendar.dateComponents([.day], from: dayZero, to: $0.date).day.map(Double.init) ?? 0 }
        let ys = window.map(\.value)

        guard let fit = Self.linearRegression(xs: xs, ys: ys) else { return nil }

        let lastX = xs.last ?? 0
        let projectedX = lastX + Double(horizonDays)
        let projectedValue = fit.intercept + fit.slope * projectedX

        let direction: TrendDirection
        if fit.slope == 0 {
            direction = .stable
        } else if fit.residualStandardError == 0 {
            // Zero residual error with a non-zero slope is a perfect noiseless
            // fit, i.e. maximally significant -- not "insignificant" even
            // though the t-statistic guard below would otherwise read 0/0 as 0.
            direction = fit.slope > 0 ? .rising : .falling
        } else if abs(fit.tStatistic) < significanceTThreshold {
            direction = .stable
        } else {
            direction = fit.slope > 0 ? .rising : .falling
        }

        // 95% CI ~ projection +/- 1.96 * residual standard error, widened
        // slightly for the extrapolation horizon.
        let margin = 1.96 * fit.residualStandardError * sqrt(1 + 1 / Double(xs.count))
        let interval = (projectedValue - margin)...(projectedValue + margin)

        return ForecastResult(
            horizonDays: horizonDays,
            projectedValue: projectedValue,
            confidenceInterval: interval,
            direction: direction,
            slopePerDay: fit.slope
        )
    }

    struct LinearFit {
        let slope: Double
        let intercept: Double
        let residualStandardError: Double
        let tStatistic: Double
    }

    static func linearRegression(xs: [Double], ys: [Double]) -> LinearFit? {
        let n = Double(xs.count)
        guard n >= 3 else { return nil }
        let xMean = xs.reduce(0, +) / n
        let yMean = ys.reduce(0, +) / n

        var sumXX = 0.0
        var sumXY = 0.0
        for (x, y) in zip(xs, ys) {
            sumXX += (x - xMean) * (x - xMean)
            sumXY += (x - xMean) * (y - yMean)
        }
        guard sumXX > 0 else { return nil }

        let slope = sumXY / sumXX
        let intercept = yMean - slope * xMean

        var residualSumSquares = 0.0
        for (x, y) in zip(xs, ys) {
            let predicted = intercept + slope * x
            residualSumSquares += pow(y - predicted, 2)
        }
        let degreesOfFreedom = n - 2
        guard degreesOfFreedom > 0 else { return nil }
        let residualStandardError = sqrt(residualSumSquares / degreesOfFreedom)

        let slopeStandardError = residualStandardError / sqrt(sumXX)
        let tStatistic = slopeStandardError > 0 ? slope / slopeStandardError : 0

        return LinearFit(slope: slope, intercept: intercept, residualStandardError: residualStandardError, tStatistic: tStatistic)
    }
}
