import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("themePreference") private var themePreference: AppThemeMode = .system

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "drop.fill")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            CheckInView()
                .tabItem {
                    Label("打卡", systemImage: "checkmark.seal.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(themePreference.colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WaterRecord.self, DailyHealthSnapshot.self, HabitItem.self, CheckInRecord.self], inMemory: true)
}
