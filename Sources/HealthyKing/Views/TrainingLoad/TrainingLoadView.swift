import SwiftUI
import Charts
import HealthyKingKit

struct TrainingLoadView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TrainingLoadCard(result: dataStore.trainingLoad)

                    if let load = dataStore.trainingLoad, load.isReliable {
                        explanationCard(load)
                        sourceCard(load.evidence)
                    }

                    if !dataStore.acwrHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "急性:慢性负荷比（ACWR）趋势", systemImage: "chart.xyaxis.line")
                            chart
                                .frame(height: 220)
                            Text("绿色区间为大多数运动者的适应范围（0.8–1.3）；虚线为常被运动科学文献引用的较高负荷参考线（1.5）。")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .cardStyle()
                    } else {
                        ContentUnavailableView("训练负荷数据积累中", systemImage: "figure.run", description: Text("持续记录锻炼后即可看到趋势"))
                            .cardStyle()
                    }
                }
                .padding()
            }
            .background(ScreenBackground())
            .navigationTitle("训练负荷")
            .refreshable { await dataStore.refresh() }
        }
    }

    private var chart: some View {
        Chart {
            RectangleMark(
                xStart: .value("开始", dataStore.acwrHistory.first!.date),
                xEnd: .value("结束", dataStore.acwrHistory.last!.date),
                yStart: .value("下限", 0.8),
                yEnd: .value("上限", 1.3)
            )
            .foregroundStyle(.green.opacity(0.12))

            ForEach(dataStore.acwrHistory, id: \.date) { sample in
                AreaMark(x: .value("日期", sample.date), y: .value("ACWR", sample.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [Brand.primary.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("日期", sample.date), y: .value("ACWR", sample.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Brand.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            RuleMark(y: .value("较高负荷参考线", 1.5))
                .foregroundStyle(.red.opacity(0.5))
                .lineStyle(StrokeStyle(dash: [4, 4]))
        }
    }

    private func explanationCard(_ load: TrainingLoadResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "为什么是这个结论", systemImage: "list.bullet.clipboard")
            Text(load.summarySentence)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                comparisonRow("近7天日均负荷", value: load.evidence.recentDailyAverage, tint: Brand.primary)
                comparisonRow("28天日均基线", value: load.evidence.chronicDailyAverage, tint: .secondary)
            }

            Text(load.actionSentence)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func sourceCard(_ evidence: TrainingLoadEvidence) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "运动数据来源", systemImage: "figure.run.square.stack")
            HStack(spacing: 10) {
                sourceTile("近7天", value: evidence.recentCompositionText, detail: "\(Int(evidence.recentDurationMinutes.rounded())) 分钟")
                sourceTile("近28天", value: evidence.chronicCompositionText, detail: "\(Int(evidence.chronicDurationMinutes.rounded())) 分钟")
            }
            if let latest = evidence.latestSession {
                Divider().opacity(0.4)
                HStack(spacing: 10) {
                    Image(systemName: latest.isSupplementalWalking ? "figure.walk.circle.fill" : "figure.run.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近记录：\(latest.activityName)")
                            .font(.subheadline.weight(.semibold))
                        Text("\(Self.dateFormatter.string(from: latest.startDate)) · \(Int(latest.durationMinutes.rounded())) 分钟\(latest.averageHeartRate.map { " · 平均心率 \(Int($0.rounded()))" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            Text("正式锻炼优先使用运动时的平均心率估算负荷；没有心率的记录会按运动类型保守估算。没有正式锻炼的日子，会用步数补充日常步行负荷。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func comparisonRow(_ title: String, value: Double, tint: Color) -> some View {
        let maxValue = max(dataStore.trainingLoad?.evidence.recentDailyAverage ?? 0, dataStore.trainingLoad?.evidence.chronicDailyAverage ?? 0, 1)
        return HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 94, alignment: .leading)
            GeometryReader { geo in
                Capsule()
                    .fill(tint.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * min(value / maxValue, 1))
                    }
            }
            .frame(height: 10)
            Text("\(Int(value.rounded()))")
                .font(.caption.bold().monospacedDigit())
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func sourceTile(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private extension TrainingLoadEvidence {
    var chronicCompositionText: String {
        if chronicFormalWorkoutCount > 0 && chronicWalkingDays > 0 {
            return "\(chronicFormalWorkoutCount) 次锻炼 + \(chronicWalkingDays) 天步行"
        }
        if chronicFormalWorkoutCount > 0 {
            return "\(chronicFormalWorkoutCount) 次锻炼"
        }
        if chronicWalkingDays > 0 {
            return "\(chronicWalkingDays) 天日常步行"
        }
        return "暂无运动记录"
    }
}
