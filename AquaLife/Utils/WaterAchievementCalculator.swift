import Foundation

struct WaterAchievement: Equatable {
    let currentStreak: Int
    let bestStreak: Int
    let reachedToday: Bool
}

enum WaterAchievementCalculator {
    static func achievement(
        records: [WaterStatsCalculator.Record],
        goal: Double,
        endingAt date: Date = .now,
        calendar: Calendar = .current
    ) -> WaterAchievement {
        let safeGoal = max(goal, 1)
        let today = calendar.startOfDay(for: date)
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let reachedDays = Set(grouped.filter { $0.value >= safeGoal }.map(\.key))
        var current = 0
        var cursor = today
        while reachedDays.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let sortedDays = reachedDays.sorted()
        var best = 0
        var running = 0
        var previousDay: Date?
        for day in sortedDays {
            if let previousDay,
               let next = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(next, inSameDayAs: day) {
                running += 1
            } else {
                running = 1
            }
            best = max(best, running)
            previousDay = day
        }

        return WaterAchievement(
            currentStreak: current,
            bestStreak: best,
            reachedToday: reachedDays.contains(today)
        )
    }
}
