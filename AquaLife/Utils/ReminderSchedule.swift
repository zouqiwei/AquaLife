//
//  ReminderSchedule.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import Foundation

struct ReminderSchedule: Equatable {
    let intervalHours: Int
    let startHour: Int
    let endHour: Int

    var hours: [Int] {
        guard intervalHours > 0, startHour <= endHour else { return [] }
        let boundedStart = min(max(startHour, 0), 23)
        let boundedEnd = min(max(endHour, 0), 23)
        guard boundedStart <= boundedEnd else { return [] }

        var result: [Int] = []
        var hour = boundedStart
        while hour <= boundedEnd {
            result.append(hour)
            hour += intervalHours
        }
        return result
    }
}
