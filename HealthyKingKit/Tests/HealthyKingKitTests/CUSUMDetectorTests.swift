import XCTest
@testable import HealthyKingKit

final class CUSUMDetectorTests: XCTestCase {
    func testNoAlarmOnNoiseWithinSlack() {
        let detector = CUSUMDetector(slackInSD: 0.5, thresholdInSD: 4.0)
        // Deviations of at most +-2 around a mean of 50 with SD 5 stay inside slack.
        let values: [Double] = [51, 49, 50, 52, 48, 50, 51]
        let signal = detector.detect(values: values, baselineMean: 50, baselineSD: 5)
        XCTAssertEqual(signal, .none)
    }

    func testAlarmsOnSustainedDownwardShift() {
        let detector = CUSUMDetector(slackInSD: 0.5, thresholdInSD: 4.0)
        // 7 days, 3 SD below baseline mean every day -- a real, sustained shift.
        let values = Array(repeating: 35.0, count: 7)
        let signal = detector.detect(values: values, baselineMean: 50, baselineSD: 5)
        guard case let .shiftedDown(magnitude) = signal else {
            return XCTFail("expected shiftedDown, got \(signal)")
        }
        XCTAssertGreaterThanOrEqual(magnitude, 4.0)
    }

    func testAlarmsOnSustainedUpwardShift() {
        let detector = CUSUMDetector(slackInSD: 0.5, thresholdInSD: 4.0)
        let values = Array(repeating: 65.0, count: 7)
        let signal = detector.detect(values: values, baselineMean: 50, baselineSD: 5)
        guard case let .shiftedUp(magnitude) = signal else {
            return XCTFail("expected shiftedUp, got \(signal)")
        }
        XCTAssertGreaterThanOrEqual(magnitude, 4.0)
    }

    func testNoAlarmWhenBaselineSDIsZero() {
        let detector = CUSUMDetector()
        XCTAssertEqual(detector.detect(values: [10, 20], baselineMean: 10, baselineSD: 0), .none)
    }
}
