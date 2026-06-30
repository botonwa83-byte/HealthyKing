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
    public func evaluate(
        dailyLoad: [DailySample],
        workouts: [WorkoutSummary] = [],
        asOf referenceDate: Date,
        calendar: Calendar = .current
    ) -> TrainingLoadResult {
        let evidence = makeEvidence(dailyLoad: dailyLoad, workouts: workouts, asOf: referenceDate, calendar: calendar)
        guard let earliestNeeded = calendar.date(byAdding: .day, value: -(chronicWindowDays - 1), to: referenceDate) else {
            return TrainingLoadResult(acuteLoad: 0, chronicLoad: 0, acwr: nil, zone: .detraining, isReliable: false, evidence: evidence)
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
            return TrainingLoadResult(acuteLoad: acuteLoad, chronicLoad: chronicLoad, acwr: nil, zone: .detraining, isReliable: isReliable, evidence: evidence)
        }

        let acwr = acuteLoad / chronicLoad
        let zone = TrainingLoadZone.zone(forACWR: acwr)
        return TrainingLoadResult(acuteLoad: acuteLoad, chronicLoad: chronicLoad, acwr: acwr, zone: zone, isReliable: isReliable, evidence: evidence)
    }

    private func ewma(_ values: [Double], lambda: Double) -> Double {
        guard let first = values.first else { return 0 }
        var current = first
        for value in values.dropFirst() {
            current = lambda * value + (1 - lambda) * current
        }
        return current
    }

    private func makeEvidence(
        dailyLoad: [DailySample],
        workouts: [WorkoutSummary],
        asOf referenceDate: Date,
        calendar: Calendar
    ) -> TrainingLoadEvidence {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let recentStart = calendar.date(byAdding: .day, value: -(acuteWindowDays - 1), to: referenceDay) ?? referenceDay
        let chronicStart = calendar.date(byAdding: .day, value: -(chronicWindowDays - 1), to: referenceDay) ?? referenceDay

        func isInRange(_ date: Date, start: Date) -> Bool {
            let day = calendar.startOfDay(for: date)
            return day >= start && day <= referenceDay
        }

        let recentLoads = dailyLoad.filter { isInRange($0.date, start: recentStart) }
        let chronicLoads = dailyLoad.filter { isInRange($0.date, start: chronicStart) }
        let recentLoadTotal = recentLoads.map(\.value).reduce(0, +)
        let chronicLoadTotal = chronicLoads.map(\.value).reduce(0, +)

        let recentSessions = workouts.filter { isInRange($0.startDate, start: recentStart) }
        let chronicSessions = workouts.filter { isInRange($0.startDate, start: chronicStart) }
        let latest = chronicSessions.max { $0.startDate < $1.startDate }

        return TrainingLoadEvidence(
            acuteWindowDays: acuteWindowDays,
            chronicWindowDays: chronicWindowDays,
            recentLoadTotal: recentLoadTotal,
            chronicLoadTotal: chronicLoadTotal,
            recentDailyAverage: recentLoadTotal / Double(max(acuteWindowDays, 1)),
            chronicDailyAverage: chronicLoadTotal / Double(max(chronicWindowDays, 1)),
            recentSessionCount: recentSessions.count,
            recentFormalWorkoutCount: recentSessions.filter { !$0.isSupplementalWalking }.count,
            recentWalkingDays: recentSessions.filter(\.isSupplementalWalking).count,
            recentDurationMinutes: recentSessions.map(\.durationMinutes).reduce(0, +),
            chronicSessionCount: chronicSessions.count,
            chronicFormalWorkoutCount: chronicSessions.filter { !$0.isSupplementalWalking }.count,
            chronicWalkingDays: chronicSessions.filter(\.isSupplementalWalking).count,
            chronicDurationMinutes: chronicSessions.map(\.durationMinutes).reduce(0, +),
            latestSession: latest
        )
    }
}
