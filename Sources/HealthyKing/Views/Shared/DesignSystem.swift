import SwiftUI
import Charts
import HealthyKingKit

// MARK: - Color helpers

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

/// Brand palette. Red, matching the KingFit icon, used as the app accent and
/// the basis for hero gradients.
enum Brand {
    static let primary = Color(hex: 0xE0102A)
    static let primaryLight = Color(hex: 0xFF5A5F)
    static let gradient = [Color(hex: 0xFF5A5F), Color(hex: 0xE0102A)]

    /// A diagonal brand gradient.
    static var linear: LinearGradient {
        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Domain → visual mappings

extension RecoveryBand {
    var gradientColors: [Color] {
        switch self {
        case .needsRest: return [Color(hex: 0xFF8A3D), Color(hex: 0xFF3B30)]
        case .moderate:  return [Color(hex: 0xFFD23F), Color(hex: 0xFF9F0A)]
        case .primed:    return [Color(hex: 0x34E0A1), Color(hex: 0x16A34A)]
        }
    }

    var soloColor: Color {
        switch self {
        case .needsRest: return Color(hex: 0xFF6B5B)
        case .moderate:  return Color(hex: 0xFFB020)
        case .primed:    return Color(hex: 0x2BC48A)
        }
    }
}

extension TrainingLoadZone {
    var gradientColors: [Color] {
        switch self {
        case .detraining: return [Color(hex: 0x4FACFE), Color(hex: 0x3A7BD5)]
        case .optimal:    return [Color(hex: 0x34E0A1), Color(hex: 0x11998E)]
        case .elevated:   return [Color(hex: 0xFFB347), Color(hex: 0xFF8008)]
        case .high:       return [Color(hex: 0xFF5E62), Color(hex: 0xDD2476)]
        }
    }

    var soloColor: Color { gradientColors.last ?? .accentColor }

    var icon: String {
        switch self {
        case .detraining: return "arrow.down.circle.fill"
        case .optimal:    return "checkmark.circle.fill"
        case .elevated:   return "exclamationmark.triangle.fill"
        case .high:       return "flame.fill"
        }
    }
}

extension MetricType {
    /// Two-stop gradient derived from the metric's tint, for icon chips and
    /// sparklines.
    var gradientColors: [Color] {
        switch self {
        case .heartRateVariability: return [Color(hex: 0xFF6FB5), Color(hex: 0xE83E8C)]
        case .restingHeartRate:     return [Color(hex: 0xFF6B6B), Color(hex: 0xE0102A)]
        case .respiratoryRate:      return [Color(hex: 0x5EE7DF), Color(hex: 0x12B5CB)]
        case .oxygenSaturation:     return [Color(hex: 0x4FACFE), Color(hex: 0x2563EB)]
        case .sleepDuration, .sleepEfficiency: return [Color(hex: 0x9D7BFF), Color(hex: 0x5B3CC4)]
        case .vo2Max:               return [Color(hex: 0x52E5A3), Color(hex: 0x16A34A)]
        case .bodyMass:             return [Color(hex: 0xFFB347), Color(hex: 0xF97316)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Reusable backgrounds & cards

/// Light screen background with a soft brand-tinted glow at the top — the
/// Apple-Fitness-style "alive but light" canvas.
struct ScreenBackground: View {
    var tint: Color = Brand.primary

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            RadialGradient(
                colors: [tint.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

/// Vivid gradient card (hero tiles, status cards).
struct GradientCard: ViewModifier {
    let colors: [Color]
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: (colors.last ?? .black).opacity(0.35), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func gradientCardStyle(_ colors: [Color], cornerRadius: CGFloat = 24) -> some View {
        modifier(GradientCard(colors: colors, cornerRadius: cornerRadius))
    }
}

/// Icon in a rounded gradient chip — used across rows and headers.
struct GradientIconChip: View {
    let systemName: String
    let colors: [Color]
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            )
            .shadow(color: (colors.last ?? .black).opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Mini area chart (sparkline)

/// Compact gradient-filled area chart for metric rows. The Y domain hugs the
/// data (not zero-based) so day-to-day variation is visible at a glance.
struct MiniAreaChart: View {
    let samples: [DailySample]
    var colors: [Color] = Brand.gradient

    var body: some View {
        let values = samples.map(\.value)
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let pad = Swift.max((hi - lo) * 0.18, 0.5)

        Chart(samples, id: \.date) { sample in
            AreaMark(x: .value("日期", sample.date), y: .value("值", sample.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [(colors.last ?? Brand.primary).opacity(0.30), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            LineMark(x: .value("日期", sample.date), y: .value("值", sample.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartLegend(.hidden)
    }
}
