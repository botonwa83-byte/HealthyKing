import Foundation

/// Tabular CUSUM change-point detector. Flags a *persistent* shift in a
/// metric's mean rather than reacting to single noisy days — this is what
/// lets the app say "your baseline has genuinely moved" instead of crying
/// wolf on normal day-to-day variance.
///
/// Standard formulation (Page, 1954):
///   S+_i = max(0, S+_{i-1} + (x_i - mu0 - k))
///   S-_i = min(0, S-_{i-1} + (x_i - mu0 + k))
/// An alarm fires when |S| exceeds the decision threshold h.
public struct CUSUMDetector: Sendable {
    /// Slack parameter as a fraction of one SD. 0.5 is the standard choice
    /// for detecting a shift of about 1 SD.
    public let slackInSD: Double
    /// Decision threshold as a multiple of SD. 4-5 is standard for ~1 SD
    /// shifts with a low false-alarm rate.
    public let thresholdInSD: Double

    public init(slackInSD: Double = 0.5, thresholdInSD: Double = 4.0) {
        self.slackInSD = slackInSD
        self.thresholdInSD = thresholdInSD
    }

    /// - Parameters:
    ///   - values: recent values, oldest to newest, evaluated against a
    ///     baseline established *before* this window.
    ///   - baselineMean: mean from the period preceding `values`.
    ///   - baselineSD: standard deviation from the period preceding `values`.
    public func detect(values: [Double], baselineMean: Double, baselineSD: Double) -> ChangePointSignal {
        guard baselineSD > 0, !values.isEmpty else { return .none }
        let k = slackInSD * baselineSD
        let h = thresholdInSD * baselineSD

        var sHigh = 0.0
        var sLow = 0.0
        var maxHigh = 0.0
        var minLow = 0.0

        for value in values {
            sHigh = max(0, sHigh + (value - baselineMean - k))
            sLow = min(0, sLow + (value - baselineMean + k))
            maxHigh = max(maxHigh, sHigh)
            minLow = min(minLow, sLow)
        }

        if maxHigh > h {
            return .shiftedUp(magnitudeInSD: maxHigh / baselineSD)
        } else if minLow < -h {
            return .shiftedDown(magnitudeInSD: abs(minLow) / baselineSD)
        }
        return .none
    }
}
