//
//  WaterStatsCalculator.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

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

enum WaterInsightDirection: Equatable {
    case improving
    case declining
    case steady
    case insufficientData
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

    struct Insight: Equatable {
        let direction: WaterInsightDirection
        let title: String
        let message: String
        let weakWindow: String
        let action: String
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

    static func insight(
        records: [Record],
        goal: Double,
        period: WaterStatsPeriod,
        endingAt date: Date = .now,
        calendar: Calendar = .current
    ) -> Insight {
        let summary = summary(records: records, goal: goal, period: period, endingAt: date, calendar: calendar)
        let periodRecords = records.filter { record in
            summary.days.contains { calendar.isDate($0.date, inSameDayAs: record.date) }
        }
        let weakWindow = weakestWindow(records: periodRecords, calendar: calendar)

        guard !periodRecords.isEmpty else {
            return Insight(
                direction: .insufficientData,
                title: "先建立稳定节奏",
                message: "最近记录还不够多，先把每天喝水这件事稳定下来，再看趋势会更准。",
                weakWindow: weakWindow.label,
                action: "下一杯先放在\(weakWindow.label)，用一小杯水把节奏续上。"
            )
        }

        let halfIndex = summary.days.count / 2
        let firstAverage = averageAmount(Array(summary.days.prefix(halfIndex)))
        let secondAverage = averageAmount(Array(summary.days.suffix(summary.days.count - halfIndex)))
        let deltaRatio = firstAverage > 0 ? ((secondAverage - firstAverage) / firstAverage) : (secondAverage > 0 ? 1 : 0)

        switch summary.trend {
        case .increasing:
            return Insight(
                direction: .improving,
                title: "本周期节奏在变好",
                message: "日均饮水比前半段高了\(Int(deltaRatio * 100))%，但\(weakWindow.label)仍然最容易断档。",
                weakWindow: weakWindow.label,
                action: "下一杯尽量放在\(weakWindow.label)，先补 \(weakWindow.suggestedAmount) ml，把最弱的一段托起来。"
            )
        case .decreasing:
            return Insight(
                direction: .declining,
                title: "最近节奏有点往下掉",
                message: "后半段日均饮水比前半段少了\(Int(abs(deltaRatio) * 100))%，尤其是\(weakWindow.label)更容易漏喝。",
                weakWindow: weakWindow.label,
                action: "下一杯提前放在\(weakWindow.label)，先补 \(weakWindow.suggestedAmount) ml，比较容易把节奏拉回来。"
            )
        case .stable:
            return Insight(
                direction: .steady,
                title: "最近节奏比较稳",
                message: "整体饮水量没有明显波动，\(weakWindow.label)还是最值得补强的时段。",
                weakWindow: weakWindow.label,
                action: "下一杯继续瞄准\(weakWindow.label)，先补 \(weakWindow.suggestedAmount) ml，让全天分布更均匀。"
            )
        }
    }

    private static func averageAmount(_ values: [DayAmount]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0) { $0 + $1.amount } / Double(values.count)
    }

    private static func weakestWindow(
        records: [Record],
        calendar: Calendar
    ) -> TimeWindowInsight {
        let windows = TimeWindowInsight.allCases
        guard !records.isEmpty else { return .afternoon }

        let grouped = Dictionary(grouping: records) { record in
            let hour = calendar.component(.hour, from: record.date)
            return windows.first(where: { $0.contains(hour: hour) }) ?? .afternoon
        }

        return windows.min { lhs, rhs in
            let left = grouped[lhs, default: []].reduce(0) { $0 + $1.amount }
            let right = grouped[rhs, default: []].reduce(0) { $0 + $1.amount }
            if left == right {
                return lhs.sortOrder < rhs.sortOrder
            }
            return left < right
        } ?? .afternoon
    }

    private enum TimeWindowInsight: CaseIterable {
        case morning
        case afternoon
        case evening

        var label: String {
            switch self {
            case .morning:
                return "上午 08:00-12:00"
            case .afternoon:
                return "下午 12:00-18:00"
            case .evening:
                return "晚上 18:00-22:00"
            }
        }

        var suggestedAmount: Int {
            switch self {
            case .morning:
                return 250
            case .afternoon:
                return 300
            case .evening:
                return 250
            }
        }

        var sortOrder: Int {
            switch self {
            case .morning: return 0
            case .afternoon: return 1
            case .evening: return 2
            }
        }

        func contains(hour: Int) -> Bool {
            switch self {
            case .morning:
                return hour >= 8 && hour < 12
            case .afternoon:
                return hour >= 12 && hour < 18
            case .evening:
                return hour >= 18 && hour <= 22
            }
        }
    }
}
