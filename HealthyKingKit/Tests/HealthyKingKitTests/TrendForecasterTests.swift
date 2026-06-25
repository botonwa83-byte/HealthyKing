import XCTest
@testable import HealthyKingKit

final class TrendForecasterTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func series(_ values: [Double], endingAt reference: Date, metric: MetricType = .heartRateVariability) -> MetricTimeSeries {
        let samples = values.enumerated().map { offset, value in
            DailySample(date: calendar.date(byAdding: .day, value: -(values.count - 1 - offset), to: reference)!, value: value)
        }
        return MetricTimeSeries(metric: metric, samples: samples)
    }

    func testPerfectLinearRiseIsDetectedAsRisingNotStable() {
        // y = 50 + 2x for x = 0...13, zero noise -- regression-test for the
        // residualStandardError == 0 edge case in significance testing.
        let reference = Date()
        let values = (0..<14).map { 50.0 + 2.0 * Double($0) }
        let s = series(values, endingAt: reference)

        let forecast = TrendForecaster(regressionWindowDays: 14, horizonDays: 3).forecast(for: s, asOf: reference, calendar: calendar)
        XCTAssertNotNil(forecast)
        XCTAssertEqual(forecast!.direction, .rising)
        // last x = 13, projected x = 16 -> y = 50 + 2*16 = 82
        XCTAssertEqual(forecast!.projectedValue, 82.0, accuracy: 0.01)
        XCTAssertEqual(forecast!.slopePerDay, 2.0, accuracy: 0.0001)
    }

    func testPerfectLinearFallIsDetectedAsFalling() {
        let reference = Date()
        let values = (0..<14).map { 80.0 - 1.5 * Double($0) }
        let s = series(values, endingAt: reference)

        let forecast = TrendForecaster(regressionWindowDays: 14, horizonDays: 2).forecast(for: s, asOf: reference, calendar: calendar)
        XCTAssertNotNil(forecast)
        XCTAssertEqual(forecast!.direction, .falling)
    }

    func testFlatNoisyDataIsStable() {
        let reference = Date()
        let values: [Double] = [50, 51, 49, 50, 50, 51, 49, 50, 51, 49, 50, 50, 49, 51]
        let s = series(values, endingAt: reference)

        let forecast = TrendForecaster(regressionWindowDays: 14).forecast(for: s, asOf: reference, calendar: calendar)
        XCTAssertNotNil(forecast)
        XCTAssertEqual(forecast!.direction, .stable)
    }

    func testNilWhenInsufficientData() {
        let reference = Date()
        let s = series([50, 51, 50], endingAt: reference)
        XCTAssertNil(TrendForecaster().forecast(for: s, asOf: reference, calendar: calendar))
    }
}
