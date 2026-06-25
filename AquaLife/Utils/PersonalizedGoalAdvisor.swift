import Foundation

enum WeatherHydrationBand: Equatable {
    case cool
    case mild
    case warm
    case hot
}

enum PersonalizedGoalFactorKind: Equatable {
    case activity
    case recovery
    case weather
}

struct PersonalizedGoalFactor: Equatable {
    let kind: PersonalizedGoalFactorKind
    let delta: Double
    let summary: String
}

struct PersonalizedGoalInput {
    let baselineGoal: Double
    let stepCount: Int?
    let sleepMinutes: Int?
    let weatherBand: WeatherHydrationBand?
    let previousRecommendedGoal: Double?
    let now: Date
}

struct PersonalizedGoalRecommendation: Equatable {
    let goal: Double
    let factors: [PersonalizedGoalFactor]
    let explanation: String
    let shouldHighlightUpdate: Bool
}

enum PersonalizedGoalAdvisor {
    static func recommendation(input: PersonalizedGoalInput) -> PersonalizedGoalRecommendation {
        var factors: [PersonalizedGoalFactor] = []

        if let stepFactor = activityFactor(for: input.stepCount) {
            factors.append(stepFactor)
        }
        if let sleepFactor = recoveryFactor(for: input.sleepMinutes) {
            factors.append(sleepFactor)
        }
        if let weatherFactor = weatherFactor(for: input.weatherBand) {
            factors.append(weatherFactor)
        }

        let adjustedGoal = GoalSettings.clamp(input.baselineGoal + factors.reduce(0) { $0 + $1.delta })
        let previousGoal = input.previousRecommendedGoal ?? adjustedGoal
        let shouldHighlightUpdate = adjustedGoal != previousGoal
            && abs(adjustedGoal - previousGoal) >= GoalSettings.step

        return PersonalizedGoalRecommendation(
            goal: adjustedGoal,
            factors: factors,
            explanation: explanation(
                for: factors,
                baselineGoal: input.baselineGoal,
                recommendedGoal: adjustedGoal
            ),
            shouldHighlightUpdate: shouldHighlightUpdate
        )
    }

    static func activityFactor(for steps: Int?) -> PersonalizedGoalFactor? {
        guard let steps else { return nil }

        let delta: Double
        switch steps {
        case ..<8_000:
            delta = 0
        case 8_000..<12_000:
            delta = 100
        case 12_000..<16_000:
            delta = 300
        default:
            delta = 400
        }

        guard delta > 0 else { return nil }
        return PersonalizedGoalFactor(kind: .activity, delta: delta, summary: "今天活动量偏高")
    }

    static func recoveryFactor(for sleepMinutes: Int?) -> PersonalizedGoalFactor? {
        guard let sleepMinutes else { return nil }

        let delta: Double
        switch sleepMinutes {
        case 480...:
            delta = 0
        case 360..<480:
            delta = 100
        default:
            delta = 200
        }

        guard delta > 0 else { return nil }
        return PersonalizedGoalFactor(kind: .recovery, delta: delta, summary: "昨晚睡眠偏少")
    }

    static func weatherFactor(for band: WeatherHydrationBand?) -> PersonalizedGoalFactor? {
        guard let band else { return nil }

        let delta: Double
        let summary: String
        switch band {
        case .cool, .mild:
            delta = 0
            summary = ""
        case .warm:
            delta = 100
            summary = "今天偏暖"
        case .hot:
            delta = 200
            summary = "今天较热"
        }

        guard delta > 0 else { return nil }
        return PersonalizedGoalFactor(kind: .weather, delta: delta, summary: summary)
    }

    private static func explanation(
        for factors: [PersonalizedGoalFactor],
        baselineGoal: Double,
        recommendedGoal: Double
    ) -> String {
        guard !factors.isEmpty else {
            return "今天可用数据有限，先按当前目标 \(Int(baselineGoal)) ml 保持稳定节奏。"
        }

        let reasons = factors.map(\.summary).joined(separator: "，")
        return "\(reasons)，建议把今日目标调整到 \(Int(recommendedGoal)) ml。"
    }
}
