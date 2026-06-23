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
            return "当前进度不落后，继续保持稳定补水。"
        case .behind:
            return "距离今日目标还差 \(Int(remaining)) ml，建议分 \(recommendedServings) 次慢慢喝完。"
        }
    }
}

enum WaterIntakeAdvisor {
    static func advice(current: Double, goal: Double, hour: Int) -> WaterIntakeAdvice {
        let safeGoal = max(goal, 1)
        let remaining = max(safeGoal - current, 0)
        let expected = expectedProgress(goal: safeGoal, hour: hour)

        if remaining == 0 {
            return WaterIntakeAdvice(status: .completed, expectedProgress: expected, remaining: 0, recommendedServings: 0)
        }

        let servings = max(1, Int(ceil(remaining / 350)))
        let status: WaterAdviceStatus = current + 100 >= expected ? .onTrack : .behind
        return WaterIntakeAdvice(status: status, expectedProgress: expected, remaining: remaining, recommendedServings: servings)
    }

    private static func expectedProgress(goal: Double, hour: Int) -> Double {
        let activeStart = 8
        let activeEnd = 22
        let clampedHour = min(max(hour, activeStart), activeEnd)
        let ratio = Double(clampedHour - activeStart) / Double(activeEnd - activeStart)
        return (goal * ratio / 100).rounded() * 100
    }
}
