import Foundation

/// Acute:Chronic Workload Ratio using exponentially-weighted moving
/// averages (Williams et al. 2016) rather than simple rolling sums — EWMA
/// avoids the artificial step-changes that plain 7-day/28-day rolling
/// averages produce when a hard training day drops out of the window.
///
/// Time constants follow the standard convention lambda = 2/(N+1):
///   acute (7-day):   lambda ~= 0.25
///   chronic (28-day): lambda ~= 0.069
public struct ACWRCalculator: Sendable {
    public let acuteWindowDays: Int
    public let chronicWindowDays: Int

    public init(acuteWindowDays: Int = 7, chronicWindowDays: Int = 28) {
        self.acuteWindowDays = acuteWindowDays
        self.chronicWindowDays = chronicWindowDays
    }

    /// - Parameter dailyLoad: TRIMP (or other load metric) per day. Missing
    ///   days are treated as zero load, which is the correct convention for
    ///   training-load EWMA (a rest day genuinely contributes zero).
    public func evaluate(dailyLoad: [DailySample], asOf referenceDate: Date, calendar: Calendar = .current) -> TrainingLoadResult {
        guard let earliestNeeded = calendar.date(byAdding: .day, value: -(chronicWindowDays - 1), to: referenceDate) else {
            return TrainingLoadResult(acuteLoad: 0, chronicLoad: 0, acwr: nil, zone: .detraining, isReliable: false)
        }

        let loadByDay = Dictionary(uniqueKeysWithValues: dailyLoad.map { (calendar.startOfDay(for: $0.date), $0.value) })
        var series: [Double] = []
        var day = calendar.startOfDay(for: earliestNeeded)
        let lastDay = calendar.startOfDay(for: referenceDate)
        var daysWithAnyData = 0
        while day <= lastDay {
            let value = loadByDay[day] ?? 0
            if loadByDay[day] != nil { daysWithAnyData += 1 }
            series.append(value)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let acuteLambda = 2.0 / (Double(acuteWindowDays) + 1.0)
        let chronicLambda = 2.0 / (Double(chronicWindowDays) + 1.0)
        let acuteLoad = ewma(series, lambda: acuteLambda)
        let chronicLoad = ewma(series, lambda: chronicLambda)

        // Need enough historical coverage for the chronic baseline to mean
        // anything; otherwise an early ratio could be wildly misleading.
        let isReliable = daysWithAnyData >= max(7, chronicWindowDays / 4)

        guard chronicLoad > 0 else {
            return TrainingLoadResult(acuteLoad: acuteLoad, chronicLoad: chronicLoad, acwr: nil, zone: .detraining, isReliable: isReliable)
        }

        let acwr = acuteLoad / chronicLoad
        let zone = TrainingLoadZone.zone(forACWR: acwr)
        return TrainingLoadResult(acuteLoad: acuteLoad, chronicLoad: chronicLoad, acwr: acwr, zone: zone, isReliable: isReliable)
    }

    private func ewma(_ values: [Double], lambda: Double) -> Double {
        guard let first = values.first else { return 0 }
        var current = first
        for value in values.dropFirst() {
            current = lambda * value + (1 - lambda) * current
        }
        return current
    }
}
