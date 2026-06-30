import SwiftUI
import HealthyKingKit

struct TrainingLoadCard: View {
    let result: TrainingLoadResult?

    var body: some View {
        if let result, result.isReliable, let acwr = result.acwr {
            reliableCard(result, acwr: acwr)
        } else {
            calibratingCard
        }
    }

    private func reliableCard(_ result: TrainingLoadResult, acwr: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("训练负荷", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.zone.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.zone.soloColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(result.zone.soloColor.opacity(0.14), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.2f", acwr))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text("ACWR · 急慢性负荷比")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.zone.gentleHeadline)
                .font(.title3.weight(.bold))
                .foregroundStyle(result.zone.soloColor)

            Text(result.summarySentence)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                LoadMiniStat(
                    title: "近7天",
                    value: result.evidence.recentDurationText,
                    subtitle: result.evidence.recentCompositionText
                )
                LoadMiniStat(
                    title: "28天基线",
                    value: result.evidence.chronicDurationText,
                    subtitle: "日均 \(Int(result.evidence.chronicDailyAverage.rounded())) 负荷"
                )
            }

            ActivityPathBand(acwr: acwr, currentZone: result.zone)

            Text(result.actionSentence)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private var calibratingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "训练负荷", systemImage: "figure.run")
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .foregroundStyle(.secondary)
                Text("训练数据积累中，再坚持几次记录的锻炼或多走动后即可生成负荷评估。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

private struct LoadMiniStat: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Activity Path band (Gentler-Streak-style zoned gauge)

/// A horizontal "activity path" gauge: a smooth multi-zone gradient track with
/// a marker showing where today's acute:chronic workload ratio sits, plus the
/// four zone labels beneath. Echoes Gentler Streak's signature Activity Path.
private struct ActivityPathBand: View {
    let acwr: Double
    let currentZone: TrainingLoadZone

    // Display domain for the ACWR axis. Chosen so the optimal band sits
    // comfortably mid-track and the extremes have room to breathe.
    private let lo = 0.5
    private let hi = 1.9

    /// Zone boundaries in ACWR units, mapped to fractional positions on track.
    private var boundaries: [Double] { [0.8, 1.3, 1.5] }

    private func position(for value: Double) -> Double {
        let clamped = min(max(value, lo), hi)
        return (clamped - lo) / (hi - lo)
    }

    private var trackGradient: LinearGradient {
        let detrain = TrainingLoadZone.detraining.soloColor
        let optimal = TrainingLoadZone.optimal.soloColor
        let elevated = TrainingLoadZone.elevated.soloColor
        let high = TrainingLoadZone.high.soloColor
        let b0 = position(for: 0.8)
        let b1 = position(for: 1.3)
        let b2 = position(for: 1.5)
        return LinearGradient(
            stops: [
                .init(color: detrain, location: 0),
                .init(color: detrain, location: b0 * 0.7),
                .init(color: optimal, location: (b0 + b1) / 2),
                .init(color: elevated, location: (b1 + b2) / 2),
                .init(color: high, location: min(b2 + 0.12, 1)),
                .init(color: high, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let trackHeight: CGFloat = 14
                let markerSize: CGFloat = 22
                let x = width * position(for: acwr)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackGradient)
                        .frame(height: trackHeight)

                    // Faint zone dividers.
                    ForEach(boundaries, id: \.self) { bound in
                        Rectangle()
                            .fill(.white.opacity(0.55))
                            .frame(width: 1.5, height: trackHeight)
                            .offset(x: width * position(for: bound) - 0.75)
                    }

                    // Current-position marker.
                    Circle()
                        .fill(.white)
                        .frame(width: markerSize, height: markerSize)
                        .overlay(Circle().stroke(currentZone.soloColor, lineWidth: 4))
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                        .offset(x: min(max(x - markerSize / 2, 0), width - markerSize))
                        .animation(.easeInOut(duration: 0.6), value: acwr)
                }
                .frame(height: markerSize)
            }
            .frame(height: 22)

            HStack(spacing: 0) {
                zoneLabel("偏低", .detraining)
                zoneLabel("适中", .optimal)
                zoneLabel("偏高", .elevated)
                zoneLabel("过高", .high)
            }
        }
    }

    private func zoneLabel(_ text: String, _ zone: TrainingLoadZone) -> some View {
        Text(text)
            .font(.caption2.weight(zone == currentZone ? .bold : .regular))
            .foregroundStyle(zone == currentZone ? zone.soloColor : .secondary)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Kind, human status wording (Gentler-Streak tone)

private extension TrainingLoadZone {
    var gentleHeadline: String {
        switch self {
        case .detraining: return "可以再活跃一点"
        case .optimal: return "状态正好，继续保持"
        case .elevated: return "注意节奏，适当放缓"
        case .high: return "该好好恢复一下了"
        }
    }
}

extension TrainingLoadResult {
    var summarySentence: String {
        let evidence = evidence
        guard evidence.hasRecentMovement else {
            return "近 \(evidence.acuteWindowDays) 天几乎没有记录到运动负荷，当前判断主要来自近期活动缺口。"
        }
        guard let acwr else {
            return "已读取到运动记录，但还需要更多连续数据来建立 28 天负荷基线。"
        }
        let relation: String
        if acwr < 0.8 {
            relation = "低于"
        } else if acwr <= 1.3 {
            relation = "接近"
        } else {
            relation = "高于"
        }
        return "近 \(evidence.acuteWindowDays) 天日均负荷 \(Int(evidence.recentDailyAverage.rounded()))，\(relation) 你的 28 天日均基线 \(Int(evidence.chronicDailyAverage.rounded()))。"
    }

    var actionSentence: String {
        let source = evidence.primarySourceText
        switch zone {
        case .detraining:
            return "\(source)。如果今天状态正常，可以安排轻松有氧或力量恢复训练，把节奏逐步找回来。"
        case .optimal:
            return "\(source)。近期负荷和长期基线匹配，按原计划训练即可。"
        case .elevated:
            return "\(source)。近期负荷上升较快，今天更适合中低强度或缩短训练时长。"
        case .high:
            return "\(source)。近期负荷明显偏高，建议优先恢复，避免连续高强度。"
        }
    }
}

extension TrainingLoadEvidence {
    var recentDurationText: String {
        guard recentDurationMinutes > 0 else { return "0 分钟" }
        return "\(Int(recentDurationMinutes.rounded())) 分钟"
    }

    var chronicDurationText: String {
        guard chronicDurationMinutes > 0 else { return "0 分钟" }
        return "\(Int(chronicDurationMinutes.rounded())) 分钟"
    }

    var recentCompositionText: String {
        if recentFormalWorkoutCount > 0 && recentWalkingDays > 0 {
            return "\(recentFormalWorkoutCount) 次锻炼 + \(recentWalkingDays) 天步行"
        }
        if recentFormalWorkoutCount > 0 {
            return "\(recentFormalWorkoutCount) 次锻炼"
        }
        if recentWalkingDays > 0 {
            return "\(recentWalkingDays) 天日常步行"
        }
        return "暂无运动记录"
    }

    var primarySourceText: String {
        if let latestSession {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: latestSession.startDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0
            let dayText = days == 0 ? "今天" : days == 1 ? "昨天" : "\(days) 天前"
            return "最近一次记录是\(dayText)的\(latestSession.activityName)，约 \(Int(latestSession.durationMinutes.rounded())) 分钟"
        }
        return "近 \(acuteWindowDays) 天主要没有正式锻炼记录"
    }
}
