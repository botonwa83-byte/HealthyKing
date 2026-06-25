import Foundation

/// Composite 0-100 recovery score, built as a transparent weighted sum of
/// per-metric z-scores against the user's own baseline — never a black box.
/// Every point on the score can be traced back to "HRV contributed +6,
/// resting HR contributed -3, ...", directly addressing the most common
/// complaint about opaque commercial recovery scores.
public struct RecoveryScoreEngine: Sendable {
    /// Relative importance of each recovery-component metric. Must sum to
    /// 1.0; HRV is weighted highest as the most sensitive autonomic-nervous-
    /// system marker, consistent with the sports-science literature.
    public let weights: [MetricType: Double]
    private let zScoreClamp: Double = 3.0
    private let maxScoreSwing: Double = 50.0

    public init(weights: [MetricType: Double] = RecoveryScoreEngine.defaultWeights) {
        self.weights = weights
    }

    public static let defaultWeights: [MetricType: Double] = [
        .heartRateVariability: 0.40,
        .restingHeartRate: 0.30,
        .respiratoryRate: 0.15,
        .sleepEfficiency: 0.15
    ]

    public func score(from insights: [MetricType: MetricInsight]) -> RecoveryScoreResult {
        var components: [RecoveryComponent] = []
        var totalSwing = 0.0
        var anyReliable = false

        for metric in MetricType.recoveryComponents {
            let weight = weights[metric] ?? 0
            guard let insight = insights[metric] else {
                components.append(RecoveryComponent(metric: metric, zScore: nil, contributionPoints: 0))
                continue
            }
            if insight.baseline.isReliable { anyReliable = true }
            guard let z = insight.zScore else {
                components.append(RecoveryComponent(metric: metric, zScore: nil, contributionPoints: 0))
                continue
            }
            let clamped = max(-zScoreClamp, min(zScoreClamp, z.directed))
            let contribution = weight * maxScoreSwing * clamped / zScoreClamp
            totalSwing += contribution
            components.append(RecoveryComponent(metric: metric, zScore: z, contributionPoints: contribution))
        }

        let rawScore = 50.0 + totalSwing
        let score = Int(max(0, min(100, rawScore)).rounded())
        return RecoveryScoreResult(
            score: score,
            band: RecoveryBand.band(for: score),
            components: components,
            isReliable: anyReliable
        )
    }
}
