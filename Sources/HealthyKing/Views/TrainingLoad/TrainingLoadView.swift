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

                    if !dataStore.acwrHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "急性:慢性负荷比（ACWR）趋势", systemImage: "chart.xyaxis.line")
                            Chart {
                                RectangleMark(
                                    xStart: .value("开始", dataStore.acwrHistory.first!.date),
                                    xEnd: .value("结束", dataStore.acwrHistory.last!.date),
                                    yStart: .value("下限", 0.8),
                                    yEnd: .value("上限", 1.3)
                                )
                                .foregroundStyle(.green.opacity(0.12))

                                ForEach(dataStore.acwrHistory, id: \.date) { sample in
                                    LineMark(x: .value("日期", sample.date), y: .value("ACWR", sample.value))
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Color.indigo.gradient)
                                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                                }
                                RuleMark(y: .value("高风险阈值", 1.5))
                                    .foregroundStyle(.red.opacity(0.5))
                                    .lineStyle(StrokeStyle(dash: [4, 4]))
                            }
                            .frame(height: 220)

                            Text("绿色区间为大多数运动者的适应范围（0.8–1.3）；虚线为常被运动科学文献引用的较高风险参考线（1.5）。")
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
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("训练负荷")
            .refreshable { await dataStore.refresh() }
        }
    }
}
