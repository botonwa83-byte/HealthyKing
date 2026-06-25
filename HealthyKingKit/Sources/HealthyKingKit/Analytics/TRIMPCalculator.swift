import Foundation

/// Biological sex as used by the Banister/Morton individualized TRIMP
/// formula's exponential weighting constant. Defaults to the more
/// conservative (lower-weighted) male constant when unknown.
public enum BiologicalSexInput: Sendable {
    case male
    case female
    case unspecified
}

/// Individualized Training Impulse (TRIMP), per Banister (1991) / Morton et
/// al., weighting exercise duration by relative cardiovascular intensity on
/// an exponential curve rather than a flat multiplier — two 30-minute
/// sessions are not equal load if one was at 60% heart-rate-reserve and the
/// other at 90%.
///
///   TRIMP = duration_min * HRr * y
///   HRr   = (HR_avg_exercise - HR_rest) / (HR_max - HR_rest)
///   y     = 0.64 * e^(1.92 * HRr)   for male
///   y     = 0.86 * e^(1.67 * HRr)   for female
public struct TRIMPCalculator: Sendable {
    public let restingHeartRate: Double
    public let maxHeartRate: Double
    public let sex: BiologicalSexInput

    public init(restingHeartRate: Double, maxHeartRate: Double, sex: BiologicalSexInput) {
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = maxHeartRate
        self.sex = sex
    }

    /// Estimate max HR from age when no measured value is available
    /// (Tanaka et al. 2001 formula, more accurate than 220-age across ages).
    public static func estimatedMaxHeartRate(age: Int) -> Double {
        208 - 0.7 * Double(age)
    }

    public func trimp(forWorkout workout: WorkoutSummary) -> Double? {
        // Prefer measured heart rate; if the workout has none (manual entry,
        // many third-party apps, no Apple Watch), fall back to an intensity
        // estimated from the activity type so the session still counts.
        let hrReserveFraction: Double
        if let avgHR = workout.averageHeartRate, maxHeartRate > restingHeartRate {
            hrReserveFraction = (avgHR - restingHeartRate) / (maxHeartRate - restingHeartRate)
        } else if let estimated = workout.estimatedIntensityFraction {
            hrReserveFraction = estimated
        } else {
            return nil
        }
        let clamped = max(0, min(1, hrReserveFraction))
        let y: Double
        switch sex {
        case .female:
            y = 0.86 * exp(1.67 * clamped)
        case .male, .unspecified:
            y = 0.64 * exp(1.92 * clamped)
        }
        return workout.durationMinutes * clamped * y
    }

    /// Daily total load (sum of per-workout TRIMP), bucketed by calendar day.
    public func dailyLoad(forWorkouts workouts: [WorkoutSummary], calendar: Calendar = .current) -> [DailySample] {
        var byDay: [Date: Double] = [:]
        for workout in workouts {
            guard let trimp = trimp(forWorkout: workout) else { continue }
            let day = calendar.startOfDay(for: workout.startDate)
            byDay[day, default: 0] += trimp
        }
        return byDay.map { DailySample(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }
}
