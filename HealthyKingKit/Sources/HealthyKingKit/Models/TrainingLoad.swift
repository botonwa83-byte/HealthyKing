import Foundation

/// Acute:chronic workload ratio zone, based on published sports-science
/// thresholds (Gabbett 2016). Wording stays in training-load language,
/// never "injury risk score", to stay clear of diagnostic claims.
public enum TrainingLoadZone: String, Sendable {
    case detraining = "负荷偏低"
    case optimal = "负荷适中"
    case elevated = "负荷偏高"
    case high = "负荷过高"

    public static func zone(forACWR acwr: Double) -> TrainingLoadZone {
        switch acwr {
        case ..<0.8: return .detraining
        case 0.8..<1.3: return .optimal
        case 1.3..<1.5: return .elevated
        default: return .high
        }
    }

    public var recommendation: String {
        switch self {
        case .detraining: return "近期训练量低于你的常规水平，可以考虑逐步恢复强度。"
        case .optimal: return "当前训练负荷处于你的适应范围内，保持节奏即可。"
        case .elevated: return "近期训练量上升较快，建议安排一次轻量或恢复性训练。"
        case .high: return "训练负荷明显高于你的近期适应水平，建议优先安排恢复，避免连续高强度训练。"
        }
    }
}

public struct TrainingLoadResult: Sendable {
    public let acuteLoad: Double
    public let chronicLoad: Double
    public let acwr: Double?
    public let zone: TrainingLoadZone
    public let isReliable: Bool
}
