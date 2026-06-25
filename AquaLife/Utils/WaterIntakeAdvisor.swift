//
//  WaterIntakeAdvisor.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import Foundation

enum WaterAdviceStatus: Equatable {
    case completed
    case onTrack
    case behind
}

struct WaterIntakeAdvice {
    let status: WaterAdviceStatus
    let expectedProgress: Double
    let remaining: Double
    let recommendedServings: Int
    let completedServings: Int
    let nextSuggestedTime: Date?
    let nextSuggestedAmount: Double?

    var title: String {
        switch status {
        case .completed:
            return "今日目标已完成"
        case .onTrack:
            return "饮水节奏不错"
        case .behind:
            return "可以补一点水"
        }
    }

    var message: String {
        switch status {
        case .completed:
            return "已经达到今日目标，后面按口渴程度少量补充就好。"
        case .onTrack:
            if let nextSuggestedAmount {
                return "当前节奏稳定，下一杯喝 \(Int(nextSuggestedAmount)) ml，继续慢慢补水。"
            }
            return "当前进度不落后，继续保持稳定补水。"
        case .behind:
            if let nextSuggestedAmount {
                return "距离今日目标还差 \(Int(remaining)) ml，建议先补 \(Int(nextSuggestedAmount)) ml，再分次喝完。"
            }
            return "距离今日目标还差 \(Int(remaining)) ml，建议分 \(recommendedServings) 次慢慢喝完。"
        }
    }
}

enum WaterIntakeAdvisor {
    static func advice(
        current: Double,
        goal: Double,
        now: Date = .now,
        startHour: Int = 8,
        endHour: Int = 22,
        calendar: Calendar = .current
    ) -> WaterIntakeAdvice {
        let safeGoal = max(goal, 1)
        let remaining = max(safeGoal - current, 0)
        let window = planningWindow(startHour: startHour, endHour: endHour)
        let expected = expectedProgress(goal: safeGoal, now: now, window: window, calendar: calendar)

        if remaining == 0 {
            return WaterIntakeAdvice(
                status: .completed,
                expectedProgress: expected,
                remaining: 0,
                recommendedServings: 0,
                completedServings: 0,
                nextSuggestedTime: nil,
                nextSuggestedAmount: nil
            )
        }

        let servings = max(1, Int(ceil(remaining / 350)))
        let status: WaterAdviceStatus = current + 100 >= expected ? .onTrack : .behind
        let nextAmount = suggestedAmount(
            remaining: remaining,
            status: status,
            now: now,
            window: window,
            calendar: calendar
        )
        let nextTime = suggestedTime(
            now: now,
            servings: servings,
            window: window,
            calendar: calendar
        )
        let completedServings = max(0, servings - Int(ceil(max(remaining - current, 0) / 350)))

        return WaterIntakeAdvice(
            status: status,
            expectedProgress: expected,
            remaining: remaining,
            recommendedServings: servings,
            completedServings: min(completedServings, servings),
            nextSuggestedTime: nextTime,
            nextSuggestedAmount: nextAmount
        )
    }

    private static func expectedProgress(
        goal: Double,
        now: Date,
        window: PlanningWindow,
        calendar: Calendar
    ) -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        guard
            let windowStart = calendar.date(byAdding: .hour, value: window.startHour, to: startOfDay),
            let windowEnd = calendar.date(byAdding: .hour, value: window.endHour, to: startOfDay),
            windowEnd > windowStart
        else {
            return 0
        }

        if now <= windowStart { return 0 }
        if now >= windowEnd { return goal }

        let elapsed = now.timeIntervalSince(windowStart)
        let total = windowEnd.timeIntervalSince(windowStart)
        let ratio = max(0, min(elapsed / total, 1))
        return (goal * ratio / 100).rounded() * 100
    }

    private static func suggestedAmount(
        remaining: Double,
        status: WaterAdviceStatus,
        now: Date,
        window: PlanningWindow,
        calendar: Calendar
    ) -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        if let windowStart = calendar.date(byAdding: .hour, value: window.startHour, to: startOfDay),
           now <= windowStart,
           remaining >= 350 {
            return 350
        }
        if remaining <= 200 { return 200 }
        if remaining <= 300 { return 300 }
        return status == .behind ? 350 : 250
    }

    private static func suggestedTime(
        now: Date,
        servings: Int,
        window: PlanningWindow,
        calendar: Calendar
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        guard
            let windowStart = calendar.date(byAdding: .hour, value: window.startHour, to: startOfDay),
            let windowEnd = calendar.date(byAdding: .hour, value: window.endHour, to: startOfDay)
        else {
            return roundedForward(now, minutes: 15, calendar: calendar)
        }

        if now <= windowStart {
            return windowStart
        }

        if now >= windowEnd {
            return roundedForward(now, minutes: 15, calendar: calendar)
        }

        let remainingTime = windowEnd.timeIntervalSince(now)
        let spacing = remainingTime / Double(max(servings, 1))
        let candidate = now.addingTimeInterval(spacing)
        return roundedForward(candidate, minutes: 15, calendar: calendar)
    }

    private static func roundedForward(_ date: Date, minutes: Int, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = components.minute else { return date }
        let remainder = minute % minutes
        if remainder == 0 { return date }
        return calendar.date(byAdding: .minute, value: minutes - remainder, to: date) ?? date
    }

    private static func planningWindow(startHour: Int, endHour: Int) -> PlanningWindow {
        let boundedStart = min(max(startHour, 0), 23)
        let boundedEnd = min(max(endHour, 1), 23)
        guard boundedStart < boundedEnd else {
            return PlanningWindow(startHour: 8, endHour: 22)
        }
        return PlanningWindow(startHour: boundedStart, endHour: boundedEnd)
    }

    private struct PlanningWindow {
        let startHour: Int
        let endHour: Int
    }
}
