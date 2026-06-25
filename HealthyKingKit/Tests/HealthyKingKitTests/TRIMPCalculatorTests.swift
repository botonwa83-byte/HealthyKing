import XCTest
@testable import HealthyKingKit

final class TRIMPCalculatorTests: XCTestCase {
    func testTRIMPMatchesBanisterFormulaForMale() {
        let calculator = TRIMPCalculator(restingHeartRate: 50, maxHeartRate: 190, sex: .male)
        let workout = WorkoutSummary(startDate: Date(), durationMinutes: 60, averageHeartRate: 120, activityName: "Run")

        // HRr = (120-50)/(190-50) = 0.5; y = 0.64 * e^(1.92*0.5); TRIMP = 60 * 0.5 * y
        let expectedHRr = 0.5
        let expectedY = 0.64 * exp(1.92 * expectedHRr)
        let expected = 60.0 * expectedHRr * expectedY

        let trimp = calculator.trimp(forWorkout: workout)
        XCTAssertNotNil(trimp)
        XCTAssertEqual(trimp!, expected, accuracy: 1e-9)
        // Independent hand-calculation sanity check (~50.1).
        XCTAssertEqual(trimp!, 50.14, accuracy: 0.5)
    }

    func testFemaleConstantProducesDifferentLoadThanMale() {
        let workout = WorkoutSummary(startDate: Date(), durationMinutes: 60, averageHeartRate: 120, activityName: "Run")
        let male = TRIMPCalculator(restingHeartRate: 50, maxHeartRate: 190, sex: .male).trimp(forWorkout: workout)!
        let female = TRIMPCalculator(restingHeartRate: 50, maxHeartRate: 190, sex: .female).trimp(forWorkout: workout)!
        XCTAssertNotEqual(male, female)
    }

    func testHeartRateReserveFractionClampsAboveMax() {
        let calculator = TRIMPCalculator(restingHeartRate: 50, maxHeartRate: 150, sex: .male)
        // averageHeartRate exceeds maxHeartRate -- fraction must clamp to 1.0, not blow up.
        let workout = WorkoutSummary(startDate: Date(), durationMinutes: 30, averageHeartRate: 200, activityName: "Sprint")
        let expected = 30.0 * 1.0 * (0.64 * exp(1.92 * 1.0))
        XCTAssertEqual(calculator.trimp(forWorkout: workout)!, expected, accuracy: 1e-9)
    }

    func testNilWhenNoHeartRateData() {
        let calculator = TRIMPCalculator(restingHeartRate: 50, maxHeartRate: 190, sex: .male)
        let workout = WorkoutSummary(startDate: Date(), durationMinutes: 30, averageHeartRate: nil, activityName: "Walk")
        XCTAssertNil(calculator.trimp(forWorkout: workout))
    }

    func testEstimatedMaxHeartRateUsesTanakaFormula() {
        // Tanaka: 208 - 0.7*age
        XCTAssertEqual(TRIMPCalculator.estimatedMaxHeartRate(age: 30), 208 - 0.7 * 30, accuracy: 0.0001)
    }

    func testDailyLoadSumsMultipleWorkoutsOnSameDay() {
        let calculator = TRIMPCalculator(restingHeartRate: 50, maxHeartRate: 190, sex: .male)
        let calendar = Calendar(identifier: .gregorian)
        let morning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        let workouts = [
            WorkoutSummary(startDate: morning, durationMinutes: 30, averageHeartRate: 120, activityName: "Run"),
            WorkoutSummary(startDate: evening, durationMinutes: 30, averageHeartRate: 120, activityName: "Run")
        ]
        let daily = calculator.dailyLoad(forWorkouts: workouts, calendar: calendar)
        XCTAssertEqual(daily.count, 1)
        let singleWorkoutLoad = calculator.trimp(forWorkout: workouts[0])!
        XCTAssertEqual(daily[0].value, singleWorkoutLoad * 2, accuracy: 1e-9)
    }
}
