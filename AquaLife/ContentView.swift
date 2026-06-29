//
//  ContentView.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("themePreference") private var themePreference: AppThemeMode = .system

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("今日", systemImage: "drop.fill")
            }
            .tag(0)

            FitnessView()
                .tabItem {
                    Label("运动", systemImage: "figure.run")
                }
                .tag(1)

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            CheckInView()
                .tabItem {
                    Label("打卡", systemImage: "checkmark.seal.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(themePreference.colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WaterRecord.self, DailyHealthSnapshot.self, HabitItem.self, CheckInRecord.self], inMemory: true)
}
