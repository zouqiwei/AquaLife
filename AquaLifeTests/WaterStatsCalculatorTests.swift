import XCTest
@testable import AquaLife

final class WaterStatsCalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testLastDaysReturnsOldestToNewestStartOfDayDates() {
        let reference = date(2026, 6, 22, hour: 15)
        let days = WaterStatsCalculator.days(for: .sevenDays, endingAt: reference, calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, date(2026, 6, 16))
        XCTAssertEqual(days.last, date(2026, 6, 22))
    }

    func testThirtyDayPeriodHasThirtyDays() {
        let days = WaterStatsCalculator.days(for: .thirtyDays, endingAt: date(2026, 6, 22), calendar: calendar)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.first, date(2026, 5, 24))
        XCTAssertEqual(days.last, date(2026, 6, 22))
    }

    func testSummaryIncludesZeroDaysInAverageAndCompletionRate() {
        let reference = date(2026, 6, 22)
        let records = [
            WaterStatsCalculator.Record(date: date(2026, 6, 16, hour: 8), amount: 2000),
            WaterStatsCalculator.Record(date: date(2026, 6, 17, hour: 9), amount: 1000),
            WaterStatsCalculator.Record(date: date(2026, 6, 17, hour: 12), amount: 1200),
        ]

        let summary = WaterStatsCalculator.summary(
            records: records,
            goal: 2000,
            period: .sevenDays,
            endingAt: reference,
            calendar: calendar
        )

        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.totalAmount, 4200)
        XCTAssertEqual(summary.reachedGoalDays, 2)
        XCTAssertEqual(summary.averageDaily, 600)
        XCTAssertEqual(summary.completionRate, 2.0 / 7.0, accuracy: 0.0001)
    }

    func testTrendClassifiesIncreasingDecreasingAndStable() {
        XCTAssertEqual(WaterStatsCalculator.trend(firstHalfAverage: 1000, secondHalfAverage: 1200), .increasing)
        XCTAssertEqual(WaterStatsCalculator.trend(firstHalfAverage: 1000, secondHalfAverage: 800), .decreasing)
        XCTAssertEqual(WaterStatsCalculator.trend(firstHalfAverage: 1000, secondHalfAverage: 1090), .stable)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour).date!
    }
}
