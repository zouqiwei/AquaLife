import XCTest
@testable import AquaLife

final class WaterFeatureRulesTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testDrinkTypeAppliesHydrationRatio() {
        XCTAssertEqual(WaterDrinkType.water.effectiveAmount(for: 300), 300)
        XCTAssertEqual(WaterDrinkType.tea.effectiveAmount(for: 300), 270)
        XCTAssertEqual(WaterDrinkType.coffee.effectiveAmount(for: 300), 210)
        XCTAssertEqual(WaterDrinkType.sports.effectiveAmount(for: 300), 300)
        XCTAssertEqual(WaterDrinkType.other.effectiveAmount(for: 300), 240)
    }

    func testReminderScheduleCreatesTimesInsideStartAndEndHours() {
        let schedule = ReminderSchedule(intervalHours: 3, startHour: 9, endHour: 18)

        XCTAssertEqual(schedule.hours, [9, 12, 15, 18])
    }

    func testReminderScheduleRejectsInvalidRanges() {
        XCTAssertTrue(ReminderSchedule(intervalHours: 0, startHour: 8, endHour: 22).hours.isEmpty)
        XCTAssertTrue(ReminderSchedule(intervalHours: 2, startHour: 22, endHour: 8).hours.isEmpty)
    }

    func testAchievementCalculatesCurrentAndBestStreaks() {
        let records = [
            record(2026, 6, 18, amount: 2000),
            record(2026, 6, 19, amount: 2200),
            record(2026, 6, 21, amount: 2100),
            record(2026, 6, 22, amount: 2050),
            record(2026, 6, 23, amount: 2300),
        ]

        let achievement = WaterAchievementCalculator.achievement(
            records: records,
            goal: 2000,
            endingAt: date(2026, 6, 23),
            calendar: calendar
        )

        XCTAssertEqual(achievement.currentStreak, 3)
        XCTAssertEqual(achievement.bestStreak, 3)
        XCTAssertTrue(achievement.reachedToday)
    }

    private func record(_ year: Int, _ month: Int, _ day: Int, amount: Double) -> WaterStatsCalculator.Record {
        WaterStatsCalculator.Record(date: date(year, month, day), amount: amount)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }
}
