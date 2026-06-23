import SwiftData
import Foundation

@Model
final class WaterRecord {
    var id: UUID
    var amount: Double       // 单位：ml
    var timestamp: Date
    var note: String?
    var drinkTypeRawValue: String?

    init(
        amount: Double,
        timestamp: Date = .now,
        note: String? = nil,
        drinkType: WaterDrinkType = .water
    ) {
        self.id = UUID()
        self.amount = amount
        self.timestamp = timestamp
        self.note = note
        self.drinkTypeRawValue = drinkType.rawValue
    }

    var drinkType: WaterDrinkType {
        get { WaterDrinkType(rawValue: drinkTypeRawValue ?? "") ?? .water }
        set { drinkTypeRawValue = newValue.rawValue }
    }

    var effectiveAmount: Double {
        drinkType.effectiveAmount(for: amount)
    }
}

enum WaterDrinkType: String, CaseIterable, Identifiable {
    case water
    case tea
    case coffee
    case sports
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water:
            return "白水"
        case .tea:
            return "茶"
        case .coffee:
            return "咖啡"
        case .sports:
            return "运动饮料"
        case .other:
            return "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .water:
            return "drop.fill"
        case .tea:
            return "cup.and.saucer.fill"
        case .coffee:
            return "mug.fill"
        case .sports:
            return "bolt.heart.fill"
        case .other:
            return "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var hydrationRatio: Double {
        switch self {
        case .water, .sports:
            return 1
        case .tea:
            return 0.9
        case .coffee:
            return 0.7
        case .other:
            return 0.8
        }
    }

    func effectiveAmount(for amount: Double) -> Double {
        amount * hydrationRatio
    }
}
