import XCTest
@testable import AquaLife

final class GoalSettingsTests: XCTestCase {
    func testClampKeepsValidGoal() {
        XCTAssertEqual(GoalSettings.clamp(2200), 2200)
    }

    func testClampRoundsToNearestStepInsideRange() {
        XCTAssertEqual(GoalSettings.clamp(2249), 2200)
        XCTAssertEqual(GoalSettings.clamp(2250), 2300)
    }

    func testClampBoundsLowAndHighValues() {
        XCTAssertEqual(GoalSettings.clamp(100), 500)
        XCTAssertEqual(GoalSettings.clamp(5000), 4000)
    }

    func testParseGoalTextUsesPreviousValueForInvalidText() {
        XCTAssertEqual(GoalSettings.value(from: "abc", previous: 2100), 2100)
        XCTAssertEqual(GoalSettings.value(from: "", previous: 2100), 2100)
    }

    func testParseGoalTextClampsNumericText() {
        XCTAssertEqual(GoalSettings.value(from: " 3600 ", previous: 2000), 3600)
        XCTAssertEqual(GoalSettings.value(from: "450", previous: 2000), 500)
        XCTAssertEqual(GoalSettings.value(from: "4050", previous: 2000), 4000)
    }
}
