import XCTest
@testable import HealthyKingKit

final class InsightEngineTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func date(_ daysAgo: Int, from reference: Date) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
    }

    func testEndToEndDetectsSustainedHRVDrop() {
        let reference = Date()
        // 30 days of stable HRV around 50, then the most recent 7 days drop hard to 30.
        var samples: [DailySample] = (8...37).map { DailySample(date: date($0, from: reference), value: 50) }
        samples += (1...7).map { DailySample(date: date($0, from: reference), value: 30) }
        samples.append(DailySample(date: reference, value: 30))

        let series = MetricTimeSeries(metric: .heartRateVariability, samples: samples)
        let engine = InsightEngine()
        let insight = engine.insight(for: series, asOf: reference, calendar: calendar)

        XCTAssertEqual(insight.today, 30)
        XCTAssertTrue(insight.baseline.isReliable)
        XCTAssertNotNil(insight.zScore)
        XCTAssertLessThan(insight.zScore!.directed, 0, "a drop in HRV should read as a negative (worse) directed z-score")
        guard case .shiftedDown = insight.changePoint else {
            return XCTFail("expected a detected downward shift, got \(insight.changePoint)")
        }
    }

    func testInsightsDictionaryCoversAllSeries() {
        let reference = Date()
        let hrv = MetricTimeSeries(metric: .heartRateVariability, samples: (0..<20).map { DailySample(date: date($0, from: reference), value: 50) })
        let rhr = MetricTimeSeries(metric: .restingHeartRate, samples: (0..<20).map { DailySample(date: date($0, from: reference), value: 60) })

        let result = InsightEngine().insights(for: [hrv, rhr], asOf: reference, calendar: calendar)
        XCTAssertEqual(Set(result.keys), Set([.heartRateVariability, .restingHeartRate]))
    }
}
