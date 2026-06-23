import SwiftData
import Foundation

@Model
final class DailyHealthSnapshot {
    var id: UUID
    var date: Date
    var stepCount: Int
    var sleepMinutes: Int
    var heartRate: Double?
    var updatedAt: Date

    init(date: Date, stepCount: Int = 0, sleepMinutes: Int = 0, heartRate: Double? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.stepCount = stepCount
        self.sleepMinutes = sleepMinutes
        self.heartRate = heartRate
        self.updatedAt = .now
    }
}
