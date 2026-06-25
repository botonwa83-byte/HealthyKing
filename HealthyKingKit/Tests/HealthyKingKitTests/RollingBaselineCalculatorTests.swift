import XCTest
@testable import HealthyKingKit

final class RollingBaselineCalculatorTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func date(_ daysAgo: Int, from reference: Date) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
    }

    func testMeanAndStandardDeviationOnSmallSample() {
        let reference = Date()
        // 5 values: 48, 49, 50, 51, 52 -> mean 50, sample SD sqrt(10/4) = 1.5811...
        let values: [Double] = [48, 49, 50, 51, 52]
        let samples = values.enumerated().map { DailySample(date: date(4 - $0.offset, from: reference), value: $0.element) }
        let series = MetricTimeSeries(metric: .heartRateVariability, samples: samples)

        let calculator = RollingBaselineCalculator(windowDays: 30, ewmaAlpha: 0.2)
        let baseline = calculator.baseline(for: series, asOf: reference, calendar: calendar)

        XCTAssertEqual(baseline.mean, 50.0, accuracy: 0.0001)
        XCTAssertEqual(baseline.standardDeviation, 1.5811, accuracy: 0.001)
        XCTAssertEqual(baseline.sampleCount, 5)
        XCTAssertFalse(baseline.isReliable, "5 samples is below the 14-day reliability threshold")
    }

    func testReliabilityThreshold() {
        let reference = Date()
        let samples = (0..<20).map { DailySample(date: date($0, from: reference), value: 50) }
        let series = MetricTimeSeries(metric: .restingHeartRate, samples: samples)

        let calculator = RollingBaselineCalculator()
        let baseline = calculator.baseline(for: series, asOf: reference, calendar: calendar)

        XCTAssertEqual(baseline.sampleCount, 20)
        XCTAssertTrue(baseline.isReliable)
    }

    func testEWMAWeightsRecentValuesMoreHeavily() {
        let reference = Date()
        // Oldest -> newest: 10 then 20. With alpha 0.2: ewma = 0.2*20 + 0.8*10 = 12.
        let samples = [
            DailySample(date: date(1, from: reference), value: 10),
            DailySample(date: date(0, from: reference), value: 20)
        ]
        let series = MetricTimeSeries(metric: .heartRateVariability, samples: samples)
        let calculator = RollingBaselineCalculator(windowDays: 30, ewmaAlpha: 0.2)
        let baseline = calculator.baseline(for: series, asOf: reference, calendar: calendar)

        XCTAssertEqual(baseline.ewma, 12.0, accuracy: 0.0001)
    }

    func testZScoreIsNilWhenBaselineUnreliable() {
        let unreliable = BaselineStats(metric: .heartRateVariability, mean: 50, standardDeviation: 5, ewma: 50, sampleCount: 5, windowDays: 30)
        let calculator = RollingBaselineCalculator()
        XCTAssertNil(calculator.zScore(today: 60, baseline: unreliable))
    }

    func testZScoreMatchesHandComputation() {
        let baseline = BaselineStats(metric: .heartRateVariability, mean: 50, standardDeviation: 1.5811, ewma: 50, sampleCount: 20, windowDays: 30)
        let calculator = RollingBaselineCalculator()
        // today = mean + 2*SD -> raw z ~= 2.0; HRV is higher-is-better so directed == raw.
        let today = 50 + 2 * 1.5811
        let z = calculator.zScore(today: today, baseline: baseline)
        XCTAssertNotNil(z)
        XCTAssertEqual(z!.raw, 2.0, accuracy: 0.01)
        XCTAssertEqual(z!.directed, 2.0, accuracy: 0.01)
    }

    func testDirectedZScoreFlipsSignForLowerIsBetterMetrics() {
        // Resting heart rate above baseline (raw +2) is *worse* recovery, so directed should be negative.
        let z = DirectedZScore(raw: 2.0, higherIsBetter: MetricType.restingHeartRate.higherIsBetter)
        XCTAssertEqual(z.raw, 2.0)
        XCTAssertEqual(z.directed, -2.0)
    }
}
