//
//  TodayView.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import SwiftUI
import SwiftData

@MainActor
class TodayViewModel: ObservableObject {
    @Published var todayWaterMl: Double = 0
    @Published var stepCount: Int = 0
    @Published var sleepMinutes: Int = 0
    @Published var heartRate: Double? = nil
    @Published var weatherBand: WeatherHydrationBand? = nil
    @Published var weatherSnapshot: WeatherHydrationSnapshot? = nil
    @Published var isLoadingHealth = true
    @Published var showAddWater = false
    @Published var healthKitStatus: HealthKitStatus = .unknown

    let hk = HealthKitManager.shared
    let weatherProvider = WeatherHydrationProvider()

    func loadAll() async {
        isLoadingHealth = true
        async let water = hk.fetchTodayWater()
        async let steps = hk.fetchTodaySteps()
        async let sleep = hk.fetchLastNightSleep()
        async let heart = hk.fetchLatestHeartRate()
        async let currentWeather = weatherProvider.fetchCurrentWeather()

        let (w, s, sl, h, weather) = await (water, steps, sleep, heart, currentWeather)
        todayWaterMl = w
        stepCount = s
        sleepMinutes = sl
        heartRate = h
        weatherSnapshot = weather
        weatherBand = weather?.band
        healthKitStatus = hk.status
        isLoadingHealth = false
    }

    func addWater(
        _ ml: Double,
        timestamp: Date = .now,
        note: String? = nil,
        drinkType: WaterDrinkType = .water,
        context: ModelContext
    ) async {
        let record = WaterRecord(amount: ml, timestamp: timestamp, note: note, drinkType: drinkType)
        context.insert(record)
        do {
            try context.save()
        } catch {
            return
        }
        try? await hk.saveWater(amount: ml)
        if DateHelper.isSameDay(timestamp, .now) {
            todayWaterMl += record.effectiveAmount
        }
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WaterRecord> { _ in true },
        sort: \.timestamp,
        order: .reverse
    ) private var allRecords: [WaterRecord]

    @StateObject private var vm = TodayViewModel()
    @AppStorage("dailyWaterGoal") private var dailyGoal: Double = 2000
    @AppStorage("preferredDailyWaterGoal") private var preferredDailyGoal: Double = 0
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderInterval") private var reminderInterval: Int = 2
    @AppStorage("reminderStartHour") private var reminderStartHour: Int = 8
    @AppStorage("reminderEndHour") private var reminderEndHour: Int = 22
    @AppStorage("pauseReminderWhenGoalReached") private var pauseReminderWhenGoalReached = false
    @AppStorage("personalizedGoalLastRecommendedGoal") private var lastRecommendedGoal: Double = 0
    @AppStorage("personalizedGoalLastRefreshDay") private var lastRecommendationDay = ""
    @AppStorage("personalizedGoalAppliedDay") private var personalizedGoalAppliedDay = ""
    @State private var showQuickAdd = false
    @State private var recentlyDeletedRecord: DeletedWaterRecord?
    @State private var showUndoDelete = false
    @State private var editingRecord: WaterRecord?
    @State private var personalizedRecommendation: PersonalizedGoalRecommendation?

    private var todayRecords: [WaterRecord] {
        allRecords.filter { DateHelper.isSameDay($0.timestamp, .now) }
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    waterRingSection
                    personalizedGoalSection
                    // weatherDetailCard  // 已移至天气二级页面
                    smartAdviceSection
                    quickAddSection
                    healthKitStatusSection
                    healthCardsSection
                    timelineSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .task {
            let _ = await HealthKitManager.shared.requestAuthorization()
            vm.healthKitStatus = HealthKitManager.shared.status
            await vm.loadAll()
            syncPreferredGoalIfNeeded()
            refreshPersonalizedRecommendation()
        }
        .onChange(of: vm.stepCount) { _, _ in refreshPersonalizedRecommendation() }
        .onChange(of: vm.sleepMinutes) { _, _ in refreshPersonalizedRecommendation() }
        .onChange(of: vm.weatherBand) { _, _ in refreshPersonalizedRecommendation() }
        .onChange(of: preferredDailyGoal) { _, _ in refreshPersonalizedRecommendation() }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddWaterSheet { ml, timestamp, note, drinkType in
                Task {
                    await vm.addWater(
                        ml,
                        timestamp: timestamp,
                        note: note,
                        drinkType: drinkType,
                        context: modelContext
                    )
                    updateRemindersForGoalProgress()
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            EditWaterRecordSheet(record: record) { oldTimestamp, oldEffective, newTimestamp, newEffective in
                var nextTotal = vm.todayWaterMl
                if DateHelper.isSameDay(oldTimestamp, .now) {
                    nextTotal -= oldEffective
                }
                if DateHelper.isSameDay(newTimestamp, .now) {
                    nextTotal += newEffective
                }
                vm.todayWaterMl = max(0, nextTotal)
                updateRemindersForGoalProgress()
            }
        }
        .alert("已删除本地饮水记录", isPresented: $showUndoDelete) {
            Button("撤销") { undoDelete() }
            Button("知道了", role: .cancel) {
                recentlyDeletedRecord = nil
            }
        } message: {
            Text("健康 App 中已写入的数据不会同步撤销。")
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                Text(DateHelper.formatDate(.now))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
            NavigationLink {
                WeatherDetailView(snapshot: vm.weatherSnapshot)
            } label: {
                HStack(spacing: 8) {
                    if let snap = vm.weatherSnapshot {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let location = snap.locationName {
                                Text(location)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: snap.conditionSymbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 14))
                                Text("\(snap.roundedTemperatureCelsius)°")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("定位中...")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.primary.opacity(0.12))
                )
            }

            .buttonStyle(.plain)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 6 { return "🌙 深夜了，注意休息" }
        if hour < 12 { return "☀️ 早上好，开启健康的一天" }
        if hour < 18 { return "🌤 下午好，记得补充水分" }
        return "🌆 傍晚好，今天喝了多少水？"
    }

    private var waterRingSection: some View {
        VStack(spacing: 16) {
            WaterProgressRing(
                current: vm.todayWaterMl,
                goal: dailyGoal
            )
            .frame(width: 220, height: 220)

            VStack(spacing: 4) {
                Text("\(Int(vm.todayWaterMl)) ml")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text("目标 \(Int(dailyGoal)) ml")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    @ViewBuilder
    private var personalizedGoalSection: some View {
        if let recommendation = personalizedRecommendation {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: recommendation.shouldHighlightUpdate ? "target" : "drop.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.primary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日目标建议")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("建议喝到 \(Int(recommendation.goal)) ml")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(recommendation.explanation)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                if !recommendation.factors.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(recommendation.factors, id: \.kind) { factor in
                            Text(factorChipText(for: factor))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.primaryDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                Text(vm.weatherSnapshot?.statusLine ?? "当前天气暂不可用")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)

                HStack {
                    Text(hasAppliedPersonalizedGoalToday(recommendation) ? "今天已应用这条建议" : "会在今天随步数和天气轻微刷新")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Button {
                        applyPersonalizedGoal(recommendation)
                    } label: {
                        Text(hasAppliedPersonalizedGoalToday(recommendation) ? "已应用" : "应用建议")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(hasAppliedPersonalizedGoalToday(recommendation) ? AppTheme.textSecondary : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                hasAppliedPersonalizedGoalToday(recommendation)
                                ? AppTheme.textSecondary.opacity(0.12)
                                : AppTheme.primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(hasAppliedPersonalizedGoalToday(recommendation))
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速记录")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 10) {
                ForEach([150, 250, 350, 500], id: \.self) { ml in
                    QuickAddButton(ml: ml) {
                        Task {
                            await vm.addWater(Double(ml), context: modelContext)
                            updateRemindersForGoalProgress()
                        }
                    }
                }
                Button {
                    showQuickAdd = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text("自定义")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(AppTheme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Weather Detail Card
    @ViewBuilder
    private var weatherDetailCard: some View {
        if let snap = vm.weatherSnapshot {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: snap.conditionSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前天气")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        Text(snap.conditionText)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Spacer()
                    // Big temperature
                    Text("\(snap.roundedTemperatureCelsius)°")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }

                Divider().background(AppTheme.cardBorder)

                // Detail grid
                HStack(spacing: 0) {
                    WeatherMetricItem(
                        symbol: "thermometer.medium",
                        label: "体感温度",
                        value: snap.roundedFeelsLike.map { "\($0)°C" } ?? "--"
                    )
                    Divider().frame(height: 36).background(AppTheme.cardBorder)
                    WeatherMetricItem(
                        symbol: "humidity",
                        label: "湿度",
                        value: snap.humidityPercent.map { "\($0)%" } ?? "--"
                    )
                    Divider().frame(height: 36).background(AppTheme.cardBorder)
                    WeatherMetricItem(
                        symbol: "sun.max.fill",
                        label: "UV 指数",
                        value: snap.uvLabel
                    )
                    Divider().frame(height: 36).background(AppTheme.cardBorder)
                    WeatherMetricItem(
                        symbol: "drop.fill",
                        label: "建议分类",
                        value: snap.bandLabel
                    )
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private var smartAdviceSection: some View {
        let advice = WaterIntakeAdvisor.advice(
            current: vm.todayWaterMl,
            goal: dailyGoal,
            now: .now,
            startHour: reminderStartHour,
            endHour: reminderEndHour
        )

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: advice.status == .completed ? "checkmark.seal.fill" : "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(advice.status == .behind ? AppTheme.stepsColor : AppTheme.secondary)
                .frame(width: 34, height: 34)
                .background((advice.status == .behind ? AppTheme.stepsColor : AppTheme.secondary).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(advice.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(advice.message)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if advice.status != .completed {
                    if let nextTime = advice.nextSuggestedTime,
                       let nextAmount = advice.nextSuggestedAmount {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                            Text("下一杯 \(DateHelper.formatTime(nextTime))")
                                .font(.system(size: 12, weight: .semibold))
                            Text("· \(Int(nextAmount)) ml")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.primaryDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text("按当前时间，建议已喝到约 \(Int(advice.expectedProgress)) ml")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.75))
                    HStack(spacing: 6) {
                        ForEach(0..<max(advice.recommendedServings, 1), id: \.self) { index in
                            RoundedRectangle(cornerRadius: 999)
                                .fill(index == 0 ? AppTheme.primary : AppTheme.primary.opacity(0.22))
                                .frame(maxWidth: .infinity)
                                .frame(height: 6)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var healthCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日健康")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                HealthCard(
                    icon: "figure.walk",
                    title: "步数",
                    value: vm.isLoadingHealth ? "--" : "\(vm.stepCount)",
                    unit: "步",
                    color: AppTheme.stepsColor,
                    target: "目标 10,000",
                    progress: vm.isLoadingHealth ? nil : min(Double(vm.stepCount) / 10_000, 1.0)
                )
                HealthCard(
                    icon: "moon.zzz.fill",
                    title: "睡眠",
                    value: vm.isLoadingHealth ? "--" : DateHelper.minutesToHoursString(vm.sleepMinutes),
                    unit: "",
                    color: AppTheme.sleepColor,
                    target: "目标 8 小时"
                )
                if let hr = vm.heartRate {
                    HealthCard(
                        icon: "heart.fill",
                        title: "心率",
                        value: "\(Int(hr))",
                        unit: "BPM",
                        color: AppTheme.heartColor,
                        target: "正常范围"
                    )
                }
                // Weather card in health grid
                if let snap = vm.weatherSnapshot {
                    HealthCard(
                        icon: snap.conditionSymbol,
                        title: "天气",
                        value: "\(snap.roundedTemperatureCelsius)°",
                        unit: "C",
                        color: weatherCardColor(for: snap.band),
                        target: snap.conditionText
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var healthKitStatusSection: some View {
        if vm.healthKitStatus.needsUserAttention {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.text.square")
                    .foregroundColor(AppTheme.heartColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.healthKitStatus.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(vm.healthKitStatus.message)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .glassCard()
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日记录")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("共 \(todayRecords.count) 条 / 总 \(allRecords.count) 条")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.6))
            }

            if todayRecords.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "drop.degreesign.slash")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("今天还没有记录")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(todayRecords) { record in
                        WaterTimelineRow(record: record) {
                            deleteRecord(record)
                        } onEdit: {
                            editingRecord = record
                        }
                        if record.id != todayRecords.last?.id {
                            Divider().background(AppTheme.cardBorder)
                        }
                    }
                }
                .glassCard()
            }
        }
    }

    private func deleteRecord(_ record: WaterRecord) {
        recentlyDeletedRecord = DeletedWaterRecord(record: record)
        let amount = record.effectiveAmount
        modelContext.delete(record)
        do {
            try modelContext.save()
            vm.todayWaterMl = max(0, vm.todayWaterMl - amount)
            updateRemindersForGoalProgress()
            showUndoDelete = true
        } catch {
            recentlyDeletedRecord = nil
        }
    }

    private func undoDelete() {
        guard let deleted = recentlyDeletedRecord else { return }
        let restored = WaterRecord(
            amount: deleted.amount,
            timestamp: deleted.timestamp,
            note: deleted.note,
            drinkType: deleted.drinkType
        )
        modelContext.insert(restored)
        do {
            try modelContext.save()
            vm.todayWaterMl += restored.effectiveAmount
            updateRemindersForGoalProgress()
            recentlyDeletedRecord = nil
            showUndoDelete = false
        } catch {
            modelContext.delete(restored)
        }
    }

    private func updateRemindersForGoalProgress() {
        guard reminderEnabled, pauseReminderWhenGoalReached else { return }
        if vm.todayWaterMl >= dailyGoal {
            NotificationManager.shared.cancelAllReminders()
        } else {
            Task {
                await NotificationManager.shared.scheduleWaterReminders(
                    intervalHours: reminderInterval,
                    startHour: reminderStartHour,
                    endHour: reminderEndHour,
                    pauseWhenGoalReached: pauseReminderWhenGoalReached
                )
            }
        }
    }

    private func refreshPersonalizedRecommendation() {
        let previousGoal = lastRecommendationDay == todayKey && lastRecommendedGoal > 0
            ? lastRecommendedGoal
            : nil

        let recommendation = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: recommendedBaselineGoal,
                stepCount: vm.stepCount > 0 ? vm.stepCount : nil,
                sleepMinutes: vm.sleepMinutes > 0 ? vm.sleepMinutes : nil,
                weatherBand: vm.weatherBand,
                previousRecommendedGoal: previousGoal,
                now: .now
            )
        )

        personalizedRecommendation = recommendation
        lastRecommendedGoal = recommendation.goal
        lastRecommendationDay = todayKey
    }

    private func applyPersonalizedGoal(_ recommendation: PersonalizedGoalRecommendation) {
        dailyGoal = recommendation.goal
        personalizedGoalAppliedDay = todayKey
        updateRemindersForGoalProgress()
    }

    private func hasAppliedPersonalizedGoalToday(_ recommendation: PersonalizedGoalRecommendation) -> Bool {
        personalizedGoalAppliedDay == todayKey && dailyGoal == recommendation.goal
    }

    private func syncPreferredGoalIfNeeded() {
        if preferredDailyGoal <= 0 {
            preferredDailyGoal = dailyGoal
        }
    }

    private var recommendedBaselineGoal: Double {
        GoalSettings.clamp(preferredDailyGoal > 0 ? preferredDailyGoal : dailyGoal)
    }

    private var todayKey: String {
        DateHelper.storageDayKey(for: .now)
    }

    private func factorChipText(for factor: PersonalizedGoalFactor) -> String {
        switch factor.kind {
        case .activity:
            return "+\(Int(factor.delta)) ml 活动"
        case .recovery:
            return "+\(Int(factor.delta)) ml 睡眠"
        case .weather:
            return "+\(Int(factor.delta)) ml 天气"
        }
    }

    private func weatherCardColor(for band: WeatherHydrationBand) -> Color {
        switch band {
        case .cool: return Color(hex: "#74B9FF")
        case .mild: return AppTheme.secondary
        case .warm: return AppTheme.stepsColor
        case .hot:  return AppTheme.heartColor
        }
    }
}

// MARK: - WeatherMetricItem
struct WeatherMetricItem: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.primary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - QuickAddButton
struct QuickAddButton: View {
    let ml: Int
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { pressed = false }
            }
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.waterGradient)
                Text("\(ml)ml")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(AppTheme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WaterTimelineRow
struct WaterTimelineRow: View {
    let record: WaterRecord
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.waterGradient)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(record.amount)) ml")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(record.drinkType.title + " · 折算 \(Int(record.effectiveAmount)) ml")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            Spacer()
            Text(DateHelper.formatTime(record.timestamp))
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑饮水记录")
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.heartColor)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除饮水记录")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct EditWaterRecordSheet: View {
    @Bindable var record: WaterRecord
    let onSave: (Date, Double, Date, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var amountText = ""
    @State private var noteText = ""
    @State private var timestamp = Date()
    @State private var drinkType: WaterDrinkType = .water

    private var parsedAmount: Double? {
        Double(amountText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.waterGradient)
                        Text("编辑饮水记录")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("饮水量")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                            Text("ml")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        DatePicker("时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                            .foregroundColor(AppTheme.textPrimary)
                            .tint(AppTheme.primary)

                        Picker("饮品类型", selection: $drinkType) {
                            ForEach(WaterDrinkType.allCases) { type in
                                Label(type.title, systemImage: type.systemImage).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.primary)

                        TextField("备注（可选）", text: $noteText)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(12)
                            .background(AppTheme.ringTrackColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(16)
                    .glassCard()

                    Spacer()

                    Button {
                        save()
                    } label: {
                        Text("保存修改")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isValid ? AnyShapeStyle(AppTheme.waterGradient) : AnyShapeStyle(Color.gray.opacity(0.4)))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            amountText = "\(Int(record.amount))"
            noteText = record.note ?? ""
            timestamp = record.timestamp
            drinkType = record.drinkType
        }
    }

    private var isValid: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0 && amount <= 5000
    }

    private func save() {
        guard let amount = parsedAmount, amount > 0 else { return }
        let oldAmount = record.amount
        let oldEffectiveAmount = record.effectiveAmount
        let oldTimestamp = record.timestamp
        let oldNote = record.note
        let oldDrinkType = record.drinkType
        record.amount = amount
        record.timestamp = timestamp
        record.drinkType = drinkType
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        record.note = trimmedNote.isEmpty ? nil : trimmedNote
        do {
            try modelContext.save()
            onSave(oldTimestamp, oldEffectiveAmount, record.timestamp, record.effectiveAmount)
            dismiss()
        } catch {
            record.amount = oldAmount
            record.timestamp = oldTimestamp
            record.note = oldNote
            record.drinkType = oldDrinkType
        }
    }
}

private struct DeletedWaterRecord: Identifiable {
    let id: UUID
    let amount: Double
    let timestamp: Date
    let note: String?
    let drinkType: WaterDrinkType

    init(record: WaterRecord) {
        self.id = record.id
        self.amount = record.amount
        self.timestamp = record.timestamp
        self.note = record.note
        self.drinkType = record.drinkType
    }
}
