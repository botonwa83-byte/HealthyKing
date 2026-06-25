import Foundation

/// Physiological metrics tracked for personal-baseline trend analysis.
/// Each case carries directionality metadata used by the recovery engine
/// (e.g. higher HRV is "good", higher resting heart rate is "bad").
public enum MetricType: String, Codable, CaseIterable, Sendable {
    case heartRateVariability
    case restingHeartRate
    case respiratoryRate
    case oxygenSaturation
    case sleepDuration
    case sleepEfficiency
    case vo2Max
    case bodyMass

    /// Whether an increase in this metric should be read as "better" (true)
    /// or "worse" (false) for recovery purposes.
    public var higherIsBetter: Bool {
        switch self {
        case .heartRateVariability, .oxygenSaturation, .sleepDuration, .sleepEfficiency, .vo2Max:
            return true
        case .restingHeartRate, .respiratoryRate, .bodyMass:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .heartRateVariability: return "心率变异性 (HRV)"
        case .restingHeartRate: return "静息心率"
        case .respiratoryRate: return "呼吸率"
        case .oxygenSaturation: return "血氧饱和度"
        case .sleepDuration: return "睡眠时长"
        case .sleepEfficiency: return "睡眠效率"
        case .vo2Max: return "最大摄氧量 (VO2 Max)"
        case .bodyMass: return "体重"
        }
    }

    public var unit: String {
        switch self {
        case .heartRateVariability: return "ms"
        case .restingHeartRate: return "bpm"
        case .respiratoryRate: return "次/分"
        case .oxygenSaturation: return "%"
        case .sleepDuration: return "小时"
        case .sleepEfficiency: return "%"
        case .vo2Max: return "ml/kg/min"
        case .bodyMass: return "kg"
        }
    }

    /// How many days back a sample may be and still count as the "current"
    /// reading. Daily physiological metrics are usually stamped to the night
    /// they were measured (often "yesterday" by the time you look), so a
    /// strict same-day match would hide them; slow-moving metrics like weight
    /// or VO2 Max can legitimately be weeks old and still be current.
    public var freshnessWindowDays: Int {
        switch self {
        case .vo2Max, .bodyMass:
            return 30
        case .heartRateVariability, .restingHeartRate, .respiratoryRate,
             .oxygenSaturation, .sleepDuration, .sleepEfficiency:
            return 3
        }
    }

    /// Metrics that feed the composite recovery score, in priority order.
    public static let recoveryComponents: [MetricType] = [
        .heartRateVariability, .restingHeartRate, .respiratoryRate, .sleepEfficiency
    ]

    /// Every metric shown on the watch, recovery drivers first.
    public static let watchDisplayOrder: [MetricType] = [
        .heartRateVariability, .restingHeartRate, .respiratoryRate, .sleepEfficiency,
        .sleepDuration, .oxygenSaturation, .vo2Max, .bodyMass
    ]
}
