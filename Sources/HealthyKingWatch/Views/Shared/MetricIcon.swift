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
}
