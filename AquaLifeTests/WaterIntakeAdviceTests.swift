import XCTest
@testable import AquaLife

final class WaterIntakeAdviceTests: XCTestCase {
    func testAdviceShowsGoalCompletedWhenCurrentReachesGoal() {
        let advice = WaterIntakeAdvisor.advice(current: 2100, goal: 2000, hour: 14)

        XCTAssertEqual(advice.status, .completed)
        XCTAssertEqual(advice.remaining, 0)
        XCTAssertEqual(advice.recommendedServings, 0)
    }

    func testAdviceCalculatesExpectedProgressForCurrentHour() {
        let advice = WaterIntakeAdvisor.advice(current: 700, goal: 2000, hour: 12)

        XCTAssertEqual(advice.status, .behind)
        XCTAssertEqual(advice.expectedProgress, 1000)
        XCTAssertEqual(advice.remaining, 1300)
        XCTAssertEqual(advice.recommendedServings, 4)
    }

    func testAdviceTreatsAheadOfExpectedPaceAsOnTrack() {
        let advice = WaterIntakeAdvisor.advice(current: 1200, goal: 2000, hour: 10)

        XCTAssertEqual(advice.status, .onTrack)
        XCTAssertEqual(advice.expectedProgress, 500)
    }
}
