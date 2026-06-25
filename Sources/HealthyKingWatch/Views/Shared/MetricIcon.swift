import SwiftUI
import HealthyKingKit

extension MetricType {
    var symbolName: String {
        switch self {
        case .heartRateVariability: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        case .respiratoryRate: return "lungs.fill"
        case .oxygenSaturation: return "drop.fill"
        case .sleepDuration: return "bed.double.fill"
        case .sleepEfficiency: return "moon.zzz.fill"
        case .vo2Max: return "figure.run.circle.fill"
        case .bodyMass: return "scalemass.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .heartRateVariability: return .pink
        case .restingHeartRate: return .red
        case .respiratoryRate: return .cyan
        case .oxygenSaturation: return .blue
        case .sleepDuration, .sleepEfficiency: return .indigo
        case .vo2Max: return .green
        case .bodyMass: return .orange
        }
    }

    /// Compact label for the narrow watch rows.
    var shortName: String {
        switch self {
        case .heartRateVariability: return "HRV"
        case .restingHeartRate: return "静息心率"
        case .respiratoryRate: return "呼吸率"
        case .oxygenSaturation: return "血氧"
        case .sleepDuration: return "睡眠时长"
        case .sleepEfficiency: return "睡眠效率"
        case .vo2Max: return "VO₂ Max"
        case .bodyMass: return "体重"
        }
    }

    /// Decimal places appropriate for each metric's magnitude.
    func formattedValue(_ value: Double) -> String {
        switch self {
        case .heartRateVariability, .vo2Max, .sleepDuration, .bodyMass:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.0f", value)
        }
    }
}

/// Human-friendly "今天 / 昨天 / N 天前" for a sample date, so the UI never
/// implies a stale reading is from today.
func relativeDayText(for date: Date?, calendar: Calendar = .current) -> String? {
    guard let date else { return nil }
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
    switch days {
    case ..<0: return nil
    case 0: return "今天"
    case 1: return "昨天"
    default: return "\(days) 天前"
    }
}
