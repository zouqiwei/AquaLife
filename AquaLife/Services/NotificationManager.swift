//
//  NotificationManager.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 设置周期性喝水提醒
    func scheduleWaterReminders(
        intervalHours: Int,
        startHour: Int = 8,
        endHour: Int = 22,
        pauseWhenGoalReached: Bool = false
    ) async {
        let center = UNUserNotificationCenter.current()
        // 清除旧的提醒
        center.removePendingNotificationRequests(withIdentifiers: existingReminderIds())

        let schedule = ReminderSchedule(intervalHours: intervalHours, startHour: startHour, endHour: endHour)
        guard !schedule.hours.isEmpty else { return }

        let messages = [
            "💧 该喝水了！保持水分让你更有活力",
            "🌊 记得补充水分，身体会感谢你的",
            "💧 喝杯水吧，健康从小习惯开始",
            "🫧 别忘了喝水！每天 8 杯是目标",
        ]

        for (index, hour) in schedule.hours.enumerated() {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "AquaLife 喝水提醒"
            content.body = pauseWhenGoalReached
                ? "如果今天还没达标，记得慢慢补一点水"
                : messages[index % messages.count]
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "water_reminder_\(hour)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: existingReminderIds())
    }

    private func existingReminderIds() -> [String] {
        (6...23).map { "water_reminder_\($0)" }
    }
}
