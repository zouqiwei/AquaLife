import XCTest
@testable import AquaLife

final class WaterIntakeAdviceTests: XCTestCase {
    func testAdviceShowsGoalCompletedWhenCurrentReachesGoal() {
        let advice = WaterIntakeAdvisor.advice(
            current: 2100,
            goal: 2000,
            now: date(2026, 6, 23, hour: 14, minute: 0),
            startHour: 8,
            endHour: 22
        )

        XCTAssertEqual(advice.status, .completed)
        XCTAssertEqual(advice.remaining, 0)
        XCTAssertEqual(advice.recommendedServings, 0)
        XCTAssertNil(advice.nextSuggestedTime)
        XCTAssertNil(advice.nextSuggestedAmount)
    }

    func testAdviceCalculatesExpectedProgressForCurrentHour() {
        let advice = WaterIntakeAdvisor.advice(
            current: 300,
            goal: 2000,
            now: date(2026, 6, 23, hour: 12, minute: 0),
            startHour: 8,
            endHour: 22
        )

        XCTAssertEqual(advice.status, .behind)
        XCTAssertEqual(advice.expectedProgress, 600)
        XCTAssertEqual(advice.remaining, 1700)
        XCTAssertEqual(advice.recommendedServings, 5)
        XCTAssertEqual(advice.nextSuggestedAmount, 350)
        XCTAssertEqual(advice.nextSuggestedTime, date(2026, 6, 23, hour: 14, minute: 0))
    }

    func testAdviceTreatsAheadOfExpectedPaceAsOnTrack() {
        let advice = WaterIntakeAdvisor.advice(
            current: 1200,
            goal: 2000,
            now: date(2026, 6, 23, hour: 10, minute: 0),
            startHour: 8,
            endHour: 22
        )

        XCTAssertEqual(advice.status, .onTrack)
        XCTAssertEqual(advice.expectedProgress, 300)
    }

    func testAdviceAnchorsToStartOfWindowBeforePlanStarts() {
        let advice = WaterIntakeAdvisor.advice(
            current: 0,
            goal: 2000,
            now: date(2026, 6, 23, hour: 6, minute: 20),
            startHour: 8,
            endHour: 22
        )

        XCTAssertEqual(advice.nextSuggestedTime, date(2026, 6, 23, hour: 8, minute: 0))
        XCTAssertEqual(advice.nextSuggestedAmount, 350)
    }

    func testAdviceFallsBackToImmediateCatchUpAfterWindowEnds() {
        let advice = WaterIntakeAdvisor.advice(
            current: 1700,
            goal: 2000,
            now: date(2026, 6, 23, hour: 23, minute: 10),
            startHour: 8,
            endHour: 22
        )

        XCTAssertEqual(advice.status, .behind)
        XCTAssertEqual(advice.nextSuggestedTime, date(2026, 6, 23, hour: 23, minute: 15))
        XCTAssertEqual(advice.nextSuggestedAmount, 300)
    }

    func testAdviceUsesComfortRangeForSmallRemainingAmount() {
        let advice = WaterIntakeAdvisor.advice(
            current: 1840,
            goal: 2000,
            now: date(2026, 6, 23, hour: 20, minute: 0),
            startHour: 8,
            endHour: 22
        )

        XCTAssertEqual(advice.remaining, 160)
        XCTAssertEqual(advice.nextSuggestedAmount, 200)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }
}
