import XCTest
@testable import HealthyKingKit

final class ACWRCalculatorTests: XCTestCase {
    let calendar = Calendar(identifier: .gregorian)

    func dailySamples(_ values: [Double], endingAt reference: Date) -> [DailySample] {
        // values[0] is oldest, values.last is `reference` day.
        values.enumerated().map { offset, value in
            DailySample(date: calendar.date(byAdding: .day, value: -(values.count - 1 - offset), to: reference)!, value: value)
        }
    }

    func testSteadyLoadProducesACWRNearOne() {
        let reference = Date()
        let samples = dailySamples(Array(repeating: 100.0, count: 28), endingAt: reference)
        let result = ACWRCalculator().evaluate(dailyLoad: samples, asOf: reference, calendar: calendar)

        XCTAssertTrue(result.isReliable)
        XCTAssertNotNil(result.acwr)
        XCTAssertEqual(result.acwr!, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.zone, .optimal)
    }

    func testRecentSpikeProducesElevatedOrHighZone() {
        let reference = Date()
        // 21 steady days at load 100, then a sharp 7-day spike to 300.
        let values = Array(repeating: 100.0, count: 21) + Array(repeating: 300.0, count: 7)
        let samples = dailySamples(values, endingAt: reference)
        let result = ACWRCalculator().evaluate(dailyLoad: samples, asOf: reference, calendar: calendar)

        XCTAssertNotNil(result.acwr)
        XCTAssertGreaterThan(result.acwr!, 1.3, "a sharp acute spike over a steady chronic baseline should read as elevated/high load")
        XCTAssertTrue(result.zone == .elevated || result.zone == .high)
    }

    func testSuddenRestProducesDetrainingZone() {
        let reference = Date()
        // 21 steady days at load 100, then 7 days of complete rest.
        let values = Array(repeating: 100.0, count: 21) + Array(repeating: 0.0, count: 7)
        let samples = dailySamples(values, endingAt: reference)
        let result = ACWRCalculator().evaluate(dailyLoad: samples, asOf: reference, calendar: calendar)

        XCTAssertNotNil(result.acwr)
        XCTAssertLessThan(result.acwr!, 0.8)
        XCTAssertEqual(result.zone, .detraining)
    }

    func testUnreliableWhenInsufficientHistory() {
        let reference = Date()
        let samples = dailySamples([100, 100, 100], endingAt: reference)
        let result = ACWRCalculator().evaluate(dailyLoad: samples, asOf: reference, calendar: calendar)
        XCTAssertFalse(result.isReliable)
    }

    func testEvidenceSummarizesRecentWorkoutsAndWalking() {
        let reference = calendar.startOfDay(for: Date())
        let loads = dailySamples(Array(repeating: 50.0, count: 28), endingAt: reference)
        let recentRun = WorkoutSummary(
            startDate: calendar.date(byAdding: .day, value: -1, to: reference)!,
            durationMinutes: 45,
            averageHeartRate: 130,
            activityName: "跑步"
        )
        let walking = WorkoutSummary(
            startDate: calendar.date(byAdding: .day, value: -2, to: reference)!,
            durationMinutes: 30,
            averageHeartRate: nil,
            activityName: "日常步行",
            estimatedIntensityFraction: 0.4
        )
        let olderRide = WorkoutSummary(
            startDate: calendar.date(byAdding: .day, value: -14, to: reference)!,
            durationMinutes: 60,
            averageHeartRate: 120,
            activityName: "骑行"
        )

        let result = ACWRCalculator().evaluate(
            dailyLoad: loads,
            workouts: [olderRide, walking, recentRun],
            asOf: reference,
            calendar: calendar
        )

        XCTAssertEqual(result.evidence.recentSessionCount, 2)
        XCTAssertEqual(result.evidence.recentFormalWorkoutCount, 1)
        XCTAssertEqual(result.evidence.recentWalkingDays, 1)
        XCTAssertEqual(result.evidence.recentDurationMinutes, 75, accuracy: 0.01)
        XCTAssertEqual(result.evidence.chronicSessionCount, 3)
        XCTAssertEqual(result.evidence.latestSession?.activityName, "跑步")
    }
}
