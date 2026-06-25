import XCTest
@testable import HealthyKingKit

final class RecoveryScoreEngineTests: XCTestCase {
    func reliableBaseline(_ metric: MetricType) -> BaselineStats {
        BaselineStats(metric: metric, mean: 50, standardDeviation: 5, ewma: 50, sampleCount: 20, windowDays: 30)
    }

    func insight(_ metric: MetricType, directedZ: Double?) -> MetricInsight {
        MetricInsight(
            metric: metric,
            today: 50,
            baseline: reliableBaseline(metric),
            zScore: directedZ.map { DirectedZScore(raw: $0, higherIsBetter: true) },
            changePoint: .none,
            forecast: nil
        )
    }

    func testWeightedCompositeScoreMatchesHandComputation() {
        // HRV +2 SD, RHR(directed) +1 SD, respiratory 0, sleep -1 SD.
        // Using weights HRV .40, RHR .30, resp .15, sleep .15, swing 50, clamp 3:
        //   HRV:  0.40*50*2/3 = 13.3333
        //   RHR:  0.30*50*1/3 = 5.0
        //   resp: 0.15*50*0/3 = 0
        //   sleep:0.15*50*-1/3 = -2.5
        //   total = 15.8333 -> score round(65.8333) = 66
        let insights: [MetricType: MetricInsight] = [
            .heartRateVariability: insight(.heartRateVariability, directedZ: 2.0),
            .restingHeartRate: insight(.restingHeartRate, directedZ: 1.0),
            .respiratoryRate: insight(.respiratoryRate, directedZ: 0.0),
            .sleepEfficiency: insight(.sleepEfficiency, directedZ: -1.0)
        ]

        let result = RecoveryScoreEngine().score(from: insights)
        XCTAssertEqual(result.score, 66)
        XCTAssertEqual(result.band, .moderate)
        XCTAssertTrue(result.isReliable)
        XCTAssertEqual(result.components.count, MetricType.recoveryComponents.count)
    }

    func testScoreClampsAtZeroAndHundred() {
        let allBad: [MetricType: MetricInsight] = Dictionary(uniqueKeysWithValues: MetricType.recoveryComponents.map {
            ($0, insight($0, directedZ: -10))
        })
        let resultBad = RecoveryScoreEngine().score(from: allBad)
        XCTAssertEqual(resultBad.score, 0)
        XCTAssertEqual(resultBad.band, .needsRest)

        let allGood: [MetricType: MetricInsight] = Dictionary(uniqueKeysWithValues: MetricType.recoveryComponents.map {
            ($0, insight($0, directedZ: 10))
        })
        let resultGood = RecoveryScoreEngine().score(from: allGood)
        XCTAssertEqual(resultGood.score, 100)
        XCTAssertEqual(resultGood.band, .primed)
    }

    func testMissingMetricsContributeZeroNotCrash() {
        let partial: [MetricType: MetricInsight] = [
            .heartRateVariability: insight(.heartRateVariability, directedZ: 3.0)
        ]
        let result = RecoveryScoreEngine().score(from: partial)
        // Only HRV contributes: 0.40*50*3/3 = 20 -> score 70
        XCTAssertEqual(result.score, 70)
        XCTAssertTrue(result.isReliable)
    }

    func testUnreliableWhenNoBaselineIsReliable() {
        let unreliableBaseline = BaselineStats(metric: .heartRateVariability, mean: 50, standardDeviation: 5, ewma: 50, sampleCount: 3, windowDays: 30)
        let insight = MetricInsight(metric: .heartRateVariability, today: 50, baseline: unreliableBaseline, zScore: nil, changePoint: .none, forecast: nil)
        let result = RecoveryScoreEngine().score(from: [.heartRateVariability: insight])
        XCTAssertFalse(result.isReliable)
        XCTAssertEqual(result.score, 50)
    }
}
