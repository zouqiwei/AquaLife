import SwiftUI

struct ProfileView: View {
    @AppStorage("dailyWaterGoal") private var dailyGoal: Double = 2000
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderInterval") private var reminderInterval: Int = 2
    @AppStorage("reminderStartHour") private var reminderStartHour: Int = 8
    @AppStorage("reminderEndHour") private var reminderEndHour: Int = 22
    @AppStorage("pauseReminderWhenGoalReached") private var pauseReminderWhenGoalReached = false
    @AppStorage("themePreference") private var themePreference: AppThemeMode = .system

    @ObservedObject private var healthKit = HealthKitManager.shared
    @State private var goalDraft: String = ""

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("我的")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("个性化设置")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.waterGradient)
                    }

                    // Water goal section
                    SettingsSection(title: "饮水目标") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("每日目标")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("", text: $goalDraft)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                        .foregroundColor(AppTheme.primary)
                                        .font(.system(size: 16, weight: .semibold))
                                        .onSubmit { commitGoalDraft() }
                                        .onChange(of: goalDraft) { _, newValue in
                                            let filtered = newValue.filter(\.isNumber)
                                            if filtered != newValue {
                                                goalDraft = filtered
                                            }
                                        }
                                        .onChange(of: dailyGoal) { _, _ in
                                            syncGoalDraft()
                                        }
                                    Text("ml")
                                        .foregroundColor(AppTheme.textSecondary)
                                        .font(.system(size: 14))
                                }
                            }

                            // Goal slider
                            Slider(value: $dailyGoal, in: GoalSettings.minimum...GoalSettings.maximum, step: GoalSettings.step)
                                .tint(AppTheme.primary)
                                .onChange(of: dailyGoal) { _, newValue in
                                    dailyGoal = GoalSettings.clamp(newValue)
                                    syncGoalDraft()
                                }

                            HStack {
                                ForEach([1500, 2000, 2500, 3000], id: \.self) { goal in
                                    Button("\(goal)") {
                                        withAnimation {
                                            dailyGoal = GoalSettings.clamp(Double(goal))
                                            syncGoalDraft()
                                        }
                                    }
                                    .font(.system(size: 13))
                                    .foregroundColor(Int(dailyGoal) == goal ? AppTheme.primary : AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        Int(dailyGoal) == goal
                                        ? AppTheme.primary.opacity(0.15)
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Reminder section
                    SettingsSection(title: "喝水提醒") {
                        VStack(spacing: 14) {
                            HStack {
                                Label("开启提醒", systemImage: "bell.fill")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Toggle("", isOn: $reminderEnabled)
                                    .tint(AppTheme.primary)
                                    .onChange(of: reminderEnabled) { _, enabled in
                                        Task {
                                            if enabled {
                                                let granted = await NotificationManager.shared.requestAuthorization()
                                                if granted {
                                                    await rescheduleReminders()
                                                } else {
                                                    reminderEnabled = false
                                                }
                                            } else {
                                                NotificationManager.shared.cancelAllReminders()
                                            }
                                        }
                                    }
                            }

                            if reminderEnabled {
                                Divider().background(AppTheme.cardBorder)

                                HStack {
                                    Text("提醒间隔")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Picker("", selection: $reminderInterval) {
                                        ForEach([1, 2, 3, 4], id: \.self) { h in
                                            Text("每 \(h) 小时").tag(h)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppTheme.primary)
                                    .onChange(of: reminderInterval) { _, newValue in
                                        Task {
                                            await rescheduleReminders(interval: newValue)
                                        }
                                    }
                                }

                                Divider().background(AppTheme.cardBorder)

                                HStack {
                                    Text("提醒时间")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Picker("", selection: $reminderStartHour) {
                                        ForEach(6...12, id: \.self) { hour in
                                            Text("\(hour):00").tag(hour)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppTheme.primary)

                                    Text("至")
                                        .foregroundColor(AppTheme.textSecondary)

                                    Picker("", selection: $reminderEndHour) {
                                        ForEach(18...23, id: \.self) { hour in
                                            Text("\(hour):00").tag(hour)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppTheme.primary)
                                }
                                .onChange(of: reminderStartHour) { _, _ in
                                    Task { await rescheduleReminders() }
                                }
                                .onChange(of: reminderEndHour) { _, _ in
                                    Task { await rescheduleReminders() }
                                }

                                Divider().background(AppTheme.cardBorder)

                                HStack {
                                    Label("达标后弱提醒", systemImage: "checkmark.bell.fill")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Toggle("", isOn: $pauseReminderWhenGoalReached)
                                        .tint(AppTheme.primary)
                                        .onChange(of: pauseReminderWhenGoalReached) { _, _ in
                                            Task { await rescheduleReminders() }
                                        }
                                }
                            }
                        }
                    }

                    // Theme section
                    SettingsSection(title: "外观") {
                        HStack {
                            Label("主题", systemImage: "moon.fill")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $themePreference) {
                                Text("跟随系统").tag(AppThemeMode.system)
                                Text("浅色").tag(AppThemeMode.light)
                                Text("深色").tag(AppThemeMode.dark)
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.primary)
                        }
                    }

                    // HealthKit section
                    SettingsSection(title: "健康数据") {
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Label("HealthKit 连接", systemImage: "heart.fill")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(healthKit.status.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(healthKit.status == .available ? AppTheme.secondary : AppTheme.heartColor)
                                    Text(healthKit.status.message)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            Divider().background(AppTheme.cardBorder)
                            Button {
                                Task { _ = await healthKit.requestAuthorization() }
                            } label: {
                                HStack {
                                    Text("重新检查权限")
                                        .foregroundColor(AppTheme.primary)
                                    Spacer()
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                            Divider().background(AppTheme.cardBorder)
                            Button {
                                if let url = URL(string: "x-apple-health://") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Text("在健康 App 中查看")
                                        .foregroundColor(AppTheme.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                        }
                    }

                    // About
                    VStack(spacing: 4) {
                        Text("AquaLife")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Version 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            syncGoalDraft()
        }
        .onDisappear {
            commitGoalDraft()
        }
    }

    private func syncGoalDraft() {
        goalDraft = "\(Int(GoalSettings.clamp(dailyGoal)))"
    }

    private func commitGoalDraft() {
        let nextValue = GoalSettings.value(from: goalDraft, previous: dailyGoal)
        dailyGoal = nextValue
        goalDraft = "\(Int(nextValue))"
    }

    private func rescheduleReminders(interval: Int? = nil) async {
        await NotificationManager.shared.scheduleWaterReminders(
            intervalHours: interval ?? reminderInterval,
            startHour: reminderStartHour,
            endHour: reminderEndHour,
            pauseWhenGoalReached: pauseReminderWhenGoalReached
        )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(1)

            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .glassCard()
        }
    }
}
