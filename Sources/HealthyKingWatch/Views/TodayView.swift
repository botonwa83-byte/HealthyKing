import SwiftUI
import HealthyKingKit

/// Primary watch screen: a scrollable list that leads into per-metric and
/// per-score detail screens. Every row is a `NavigationLink`, so tapping
/// anything now actually goes somewhere.
struct TodayView: View {
    @EnvironmentObject private var dataStore: WatchHealthDataStore

    private var displayedMetrics: [MetricType] {
        MetricType.watchDisplayOrder.filter { dataStore.insights[$0]?.today != nil }
    }

    var body: some View {
        List {
            recoverySection
            trainingLoadSection
            metricsSection
            if let error = dataStore.lastError {
                errorSection(error)
            }
            footerSection
        }
        .navigationTitle("KingFit")
        .task {
            if !dataStore.hasLoadedOnce { await dataStore.refresh() }
        }
    }

    // MARK: Recovery

    @ViewBuilder
    private var recoverySection: some View {
        Section {
            if dataStore.recovery != nil {
                NavigationLink {
                    RecoveryDetailView()
                } label: {
                    HStack(spacing: 12) {
                        RecoveryRing(score: dataStore.recovery?.score, band: dataStore.recovery?.band, lineWidth: 7, showsBandText: false)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("恢复评分")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(dataStore.recovery?.band.rawValue ?? "")
                                .font(.headline)
                            if dataStore.recovery?.isReliable == false {
                                Text("校准中")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else if dataStore.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        }
    }

    // MARK: Training load

    @ViewBuilder
    private var trainingLoadSection: some View {
        if let load = dataStore.trainingLoad, load.isReliable {
            Section {
                NavigationLink {
                    TrainingLoadDetailView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.tint)
                            .frame(width: 20)
                        Text("训练负荷")
                            .font(.caption)
                        Spacer()
                        Text(load.zone.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Metrics

    @ViewBuilder
    private var metricsSection: some View {
        if displayedMetrics.isEmpty {
            if dataStore.hasLoadedOnce && dataStore.lastError == nil {
                Section {
                    ContentUnavailablePlaceholder(
                        title: "暂无可显示的数据",
                        message: "请确认已在 iPhone 的健康 App 中授权读取相关数据。",
                        systemImage: "heart.text.square"
                    )
                }
            }
        } else {
            Section("指标") {
                ForEach(displayedMetrics, id: \.self) { metric in
                    NavigationLink {
                        MetricDetailView(metric: metric)
                    } label: {
                        metricRow(metric)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricRow(_ metric: MetricType) -> some View {
        let insight = dataStore.insights[metric]
        HStack(spacing: 8) {
            Image(systemName: metric.symbolName)
                .font(.caption2)
                .foregroundStyle(metric.tintColor)
                .frame(width: 20)
            Text(metric.shortName)
                .font(.caption)
            Spacer()
            if let today = insight?.today {
                Text(metric.formattedValue(today))
                    .font(.caption.bold().monospacedDigit())
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            arrowIcon(for: insight?.changePoint)
        }
    }

    @ViewBuilder
    private func arrowIcon(for signal: ChangePointSignal?) -> some View {
        switch signal {
        case .shiftedUp:
            Image(systemName: "arrow.up").font(.caption2).foregroundStyle(.blue)
        case .shiftedDown:
            Image(systemName: "arrow.down").font(.caption2).foregroundStyle(.orange)
        default:
            Image(systemName: "minus").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Error & footer

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        Section {
            Button {
                Task { await dataStore.refresh() }
            } label: {
                HStack {
                    if dataStore.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(dataStore.isLoading ? "刷新中…" : "刷新")
                        .font(.caption)
                }
            }
            .disabled(dataStore.isLoading)

            if let updated = dataStore.lastUpdated {
                Text("更新于 \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
