import Foundation

enum WaterStatsPeriod: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sevenDays:
            return "7 天"
        case .thirtyDays:
            return "30 天"
        }
    }
}

enum WaterTrend: Equatable {
    case increasing
    case decreasing
    case stable

    var title: String {
        switch self {
        case .increasing:
            return "上升"
        case .decreasing:
            return "下降"
        case .stable:
            return "持平"
        }
    }

    var systemImage: String {
        switch self {
        case .increasing:
            return "arrow.up.right"
        case .decreasing:
            return "arrow.down.right"
        case .stable:
            return "minus"
        }
    }
}

enum WaterStatsCalculator {
    struct Record {
        let date: Date
        let amount: Double
    }

    struct DayAmount: Identifiable {
        let date: Date
        let amount: Double
        var id: Date { date }
    }

    struct Summary {
        let days: [DayAmount]
        let totalAmount: Double
        let reachedGoalDays: Int
        let averageDaily: Double
        let completionRate: Double
        let trend: WaterTrend
    }

    static func days(
        for period: WaterStatsPeriod,
        endingAt date: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let end = calendar.startOfDay(for: date)
        return (0..<period.rawValue).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: end)
        }
    }

    static func summary(
        records: [Record],
        goal: Double,
        period: WaterStatsPeriod,
        endingAt date: Date = .now,
        calendar: Calendar = .current
    ) -> Summary {
        let periodDays = days(for: period, endingAt: date, calendar: calendar)
        let amounts = periodDays.map { day -> DayAmount in
            let total = records
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return DayAmount(date: day, amount: total)
        }

        let total = amounts.reduce(0) { $0 + $1.amount }
        let reached = amounts.filter { $0.amount >= goal }.count
        let average = amounts.isEmpty ? 0 : total / Double(amounts.count)
        let completion = amounts.isEmpty ? 0 : Double(reached) / Double(amounts.count)
        let halfIndex = amounts.count / 2
        let firstAverage = averageAmount(Array(amounts.prefix(halfIndex)))
        let secondAverage = averageAmount(Array(amounts.suffix(amounts.count - halfIndex)))

        return Summary(
            days: amounts,
            totalAmount: total,
            reachedGoalDays: reached,
            averageDaily: average,
            completionRate: completion,
            trend: trend(firstHalfAverage: firstAverage, secondHalfAverage: secondAverage)
        )
    }

    static func trend(firstHalfAverage: Double, secondHalfAverage: Double) -> WaterTrend {
        guard firstHalfAverage > 0 else {
            return secondHalfAverage > 0 ? .increasing : .stable
        }
        if secondHalfAverage >= firstHalfAverage * 1.1 { return .increasing }
        if secondHalfAverage <= firstHalfAverage * 0.9 { return .decreasing }
        return .stable
    }

    private static func averageAmount(_ values: [DayAmount]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0) { $0 + $1.amount } / Double(values.count)
    }
}
