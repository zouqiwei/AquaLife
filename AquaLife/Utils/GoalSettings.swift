import Foundation

enum GoalSettings {
    static let minimum: Double = 500
    static let maximum: Double = 4000
    static let step: Double = 100

    static func clamp(_ value: Double) -> Double {
        let bounded = min(max(value, minimum), maximum)
        return (bounded / step).rounded() * step
    }

    static func value(from text: String, previous: Double) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue = Double(trimmed) else {
            return clamp(previous)
        }
        return clamp(rawValue)
    }
}
