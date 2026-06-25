//
//  Habit.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import SwiftData
import Foundation

@Model
final class HabitItem {
    var id: UUID
    var name: String
    var icon: String         // SF Symbol name
    var colorHex: String
    var sortOrder: Int
    var isActive: Bool
    var createdAt: Date

    init(name: String, icon: String, colorHex: String = "#34C759", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isActive = true
        self.createdAt = .now
    }

    static let defaults: [HabitItem] = [
        HabitItem(name: "早睡早起", icon: "moon.stars.fill", colorHex: "#5856D6", sortOrder: 0),
        HabitItem(name: "运动锻炼", icon: "figure.run", colorHex: "#FF9500", sortOrder: 1),
        HabitItem(name: "健康饮食", icon: "leaf.fill", colorHex: "#34C759", sortOrder: 2),
        HabitItem(name: "冥想放松", icon: "brain.head.profile", colorHex: "#AF52DE", sortOrder: 3),
    ]
}

@Model
final class CheckInRecord {
    var id: UUID
    var habitId: UUID
    var date: Date
    var note: String?

    init(habitId: UUID, date: Date = .now, note: String? = nil) {
        self.id = UUID()
        self.habitId = habitId
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
    }
}
