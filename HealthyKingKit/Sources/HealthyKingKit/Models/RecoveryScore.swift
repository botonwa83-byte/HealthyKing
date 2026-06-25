import Foundation

/// One metric's signed contribution to the composite recovery score, shown
/// to the user so the score is explainable rather than a black box.
public struct RecoveryComponent: Sendable {
    public let metric: MetricType
    public let zScore: DirectedZScore?
    /// Signed contribution to the 0-100 score, already weighted.
    public let contributionPoints: Double
}

/// Qualitative band for the composite recovery score. Wording is
/// deliberately behavioral ("建议恢复"/"状态良好"), never diagnostic.
public enum RecoveryBand: String, Sendable {
    case needsRest = "建议恢复"
    case moderate = "正常"
    case primed = "状态良好"

    public static func band(for score: Int) -> RecoveryBand {
        switch score {
        case ..<40: return .needsRest
        case 40..<70: return .moderate
        default: return .primed
        }
    }
}

public struct RecoveryScoreResult: Sendable {
    public let score: Int
    public let band: RecoveryBand
    public let components: [RecoveryComponent]
    public let isReliable: Bool
}
