import SwiftData
import Foundation

@Model
final class WaterRecord {
    var id: UUID
    var amount: Double       // 单位：ml
    var timestamp: Date
    var note: String?

    init(amount: Double, timestamp: Date = .now, note: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.timestamp = timestamp
        self.note = note
    }
}
