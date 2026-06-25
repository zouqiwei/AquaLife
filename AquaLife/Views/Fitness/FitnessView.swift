//
//  FitnessView.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/25.
//

import SwiftUI
import Charts

// MARK: - ViewModel

@MainActor
class FitnessViewModel: ObservableObject {
    @Published var stepCount: Int = 0
    @Published var activeCalories: Double = 0
    @Published var sleepMinutes: Int = 0
    @Published var heartRate: Double? = nil
    @Published var weeklySteps: [(date: Date, steps: Int)] = []
    @Published var isLoading = true

    let stepGoal = 10_000
    let calorieGoal: Double = 500
    let sleepGoalMinutes = 480 // 8 hours

    var stepProgress: Double { min(Double(stepCount) / Double(stepGoal), 1.0) }
    var calorieProgress: Double { min(activeCalories / calorieGoal, 1.0) }
    var sleepProgress: Double { min(Double(sleepMinutes) / Double(sleepGoalMinutes), 1.0) }

    var sleepRating: SleepRating {
        switch sleepMinutes {
        case 0..<1: return .noData
        case 1..<360: return .poor   // < 6h
        case 360..<420: return .fair  // 6~7h
        case 420..<480: return .good  // 7~8h
        default: return .great        // >= 8h
        }
    }

    var heartRateStatus: HeartRateStatus {
        guard let hr = heartRate else { return .noData }
        switch hr {
        case ..<60: return .low
        case 60...100: return .normal
        default: return .high
        }
    }

    func loadAll() async {
        isLoading = true
        let hk = HealthKitManager.shared
        async let steps = hk.fetchTodaySteps()
        async let cal = hk.fetchTodayActiveCalories()
        async let sleep = hk.fetchLastNightSleep()
        async let heart = hk.fetchLatestHeartRate()
        async let weekly = hk.fetchWeeklySteps()

        let (s, c, sl, h, w) = await (steps, cal, sleep, heart, weekly)
        stepCount = s
        activeCalories = c
        sleepMinutes = sl
        heartRate = h
        weeklySteps = w
        isLoading = false
    }
}

enum SleepRating {
    case noData, poor, fair, good, great
    var emoji: String {
        switch self {
        case .noData: return "❓"
        case .poor: return "😴"
        case .fair: return "😐"
        case .good: return "🙂"
        case .great: return "😊"
        }
    }
    var label: String {
        switch self {
        case .noData: return "暂无数据"
        case .poor: return "睡眠不足"
        case .fair: return "偏少"
        case .good: return "良好"
        case .great: return "充足"
        }
    }
}

enum HeartRateStatus {
    case noData, low, normal, high
    var label: String {
        switch self {
        case .noData: return "暂无数据"
        case .low: return "偏低"
        case .normal: return "正常范围"
        case .high: return "偏高"
        }
    }
    var color: Color {
        switch self {
        case .noData: return AppTheme.textSecondary
        case .low: return AppTheme.primary
        case .normal: return AppTheme.secondary
        case .high: return AppTheme.heartColor
        }
    }
}

// MARK: - Main View

struct FitnessView: View {
    @StateObject private var vm = FitnessViewModel()

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    activityRingsSection
                    stepGoalCard
                    HStack(spacing: 12) {
                        sleepCard
                        heartRateCard
                    }
                    weeklyStepsChart
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .task {
            let _ = await HealthKitManager.shared.requestAuthorization()
            await vm.loadAll()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日运动")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(formattedToday)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.stepsColor, AppTheme.caloriesColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Activity Rings

    private var activityRingsSection: some View {
        VStack(spacing: 20) {
            ActivityRingsView(
                calorieProgress: vm.calorieProgress,
                stepProgress: vm.stepProgress,
                sleepProgress: vm.sleepProgress
            )
            .frame(width: 200, height: 200)

            HStack(spacing: 20) {
                RingLegendItem(
                    color: AppTheme.caloriesColor,
                    label: "卡路里",
                    value: vm.isLoading ? "--" : "\(Int(vm.activeCalories)) kcal"
                )
                RingLegendItem(
                    color: AppTheme.stepsColor,
                    label: "步数",
                    value: vm.isLoading ? "--" : "\(vm.stepCount) 步"
                )
                RingLegendItem(
                    color: AppTheme.sleepColor,
                    label: "睡眠",
                    value: vm.isLoading ? "--" : minutesToHM(vm.sleepMinutes)
                )
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Step Goal Card

    private var stepGoalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.stepsColor)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.stepsColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("步数目标")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(vm.isLoading ? "--" : "\(vm.stepCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.stepsColor)
                Text("/ \(vm.stepGoal)")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.stepsColor.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.stepsColor, AppTheme.stepsColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * vm.stepProgress, height: 10)
                        .animation(.spring(response: 0.6), value: vm.stepProgress)
                }
            }
            .frame(height: 10)

            // Milestones
            HStack(spacing: 0) {
                ForEach([3000, 5000, 8000, 10000], id: \.self) { milestone in
                    let reached = vm.stepCount >= milestone
                    VStack(spacing: 4) {
                        Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundColor(reached ? AppTheme.stepsColor : AppTheme.textSecondary.opacity(0.4))
                        Text(milestone >= 1000 ? "\(milestone / 1000)k" : "\(milestone)")
                            .font(.system(size: 10))
                            .foregroundColor(reached ? AppTheme.stepsColor : AppTheme.textSecondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Sleep Card

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.sleepColor)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.sleepColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
                Text(vm.sleepRating.emoji)
                    .font(.system(size: 20))
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(vm.isLoading ? "--" : minutesToHM(vm.sleepMinutes))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Text("睡眠")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            Text(vm.sleepRating.label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.sleepColor.opacity(0.9))

            ZStack {
                Circle()
                    .stroke(AppTheme.sleepColor.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: vm.sleepProgress)
                    .stroke(AppTheme.sleepColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: vm.sleepProgress)
            }
            .frame(width: 36, height: 36)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.sleepColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.sleepColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Heart Rate Card

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.heartColor)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.heartColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.heartColor.opacity(0.6))
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Group {
                    if let hr = vm.heartRate {
                        Text("\(Int(hr))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        Text(vm.isLoading ? "--" : "--")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                if vm.heartRate != nil {
                    Text("BPM")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Text("心率")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Text(vm.heartRateStatus.label)
                .font(.system(size: 10))
                .foregroundColor(vm.heartRateStatus.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(vm.heartRateStatus.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.heartColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.heartColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Weekly Steps Chart

    private var weeklyStepsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近 7 天步数")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                if !vm.weeklySteps.isEmpty {
                    let avg = vm.weeklySteps.map(\.steps).reduce(0, +) / max(vm.weeklySteps.count, 1)
                    Text("均 \(avg) 步")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.stepsColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if vm.weeklySteps.isEmpty && !vm.isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                        Text("暂无步数数据")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                Chart {
                    ForEach(vm.weeklySteps, id: \.date) { item in
                        AreaMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("步数", item.steps)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.stepsColor.opacity(0.35), AppTheme.stepsColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("步数", item.steps)
                        )
                        .foregroundStyle(AppTheme.stepsColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("步数", item.steps)
                        )
                        .foregroundStyle(item.steps >= vm.stepGoal ? AppTheme.secondary : AppTheme.stepsColor)
                        .symbolSize(item.steps >= vm.stepGoal ? 60 : 30)
                    }

                    RuleMark(y: .value("目标", vm.stepGoal))
                        .foregroundStyle(AppTheme.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("目标 \(vm.stepGoal / 1000)k")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.secondary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(AppTheme.textSecondary)
                        AxisGridLine()
                            .foregroundStyle(AppTheme.cardBorder)
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .glassCard()
    }

    // MARK: - Helpers

    private var formattedToday: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: .now)
    }

    private func minutesToHM(_ min: Int) -> String {
        if min <= 0 { return "--" }
        let h = min / 60
        let m = min % 60
        if h == 0 { return "\(m)min" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - Activity Rings View

struct ActivityRingsView: View {
    let calorieProgress: Double
    let stepProgress: Double
    let sleepProgress: Double

    private let lineWidth: CGFloat = 18
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Outermost — Calories
                RingArc(
                    progress: calorieProgress,
                    radius: size / 2 - lineWidth / 2,
                    lineWidth: lineWidth,
                    center: center,
                    color: AppTheme.caloriesColor
                )
                // Middle — Steps
                RingArc(
                    progress: stepProgress,
                    radius: size / 2 - lineWidth * 1.5 - spacing,
                    lineWidth: lineWidth,
                    center: center,
                    color: AppTheme.stepsColor
                )
                // Innermost — Sleep
                RingArc(
                    progress: sleepProgress,
                    radius: size / 2 - lineWidth * 2.5 - spacing * 2,
                    lineWidth: lineWidth,
                    center: center,
                    color: AppTheme.sleepColor
                )
            }
        }
    }
}

struct RingArc: View {
    let progress: Double
    let radius: CGFloat
    let lineWidth: CGFloat
    let center: CGPoint
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)
                .position(center)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .position(center)
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

            if progress > 0.02 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth * 0.65, height: lineWidth * 0.65)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(-90 + progress * 360))
                    .position(center)
                    .shadow(color: color.opacity(0.55), radius: 4)
                    .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)
            }
        }
    }
}

// MARK: - Ring Legend

struct RingLegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
