//
//  AquaLifeApp.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import SwiftUI
import SwiftData

@main
struct AquaLifeApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: WaterRecord.self, DailyHealthSnapshot.self, HabitItem.self, CheckInRecord.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
