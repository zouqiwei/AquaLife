import SwiftUI
import SwiftData

@MainActor
class TodayViewModel: ObservableObject {
    @Published var todayWaterMl: Double = 0
    @Published var stepCount: Int = 0
    @Published var sleepMinutes: Int = 0
    @Published var heartRate: Double? = nil
    @Published var isLoadingHealth = true
    @Published var showAddWater = false
    @Published var healthKitStatus: HealthKitStatus = .unknown

    let hk = HealthKitManager.shared

    func loadAll() async {
        isLoadingHealth = true
        async let water = hk.fetchTodayWater()
        async let steps = hk.fetchTodaySteps()
        async let sleep = hk.fetchLastNightSleep()
        async let heart = hk.fetchLatestHeartRate()

        let (w, s, sl, h) = await (water, steps, sleep, heart)
        todayWaterMl = w
        stepCount = s
        sleepMinutes = sl
        heartRate = h
        healthKitStatus = hk.status
        isLoadingHealth = false
    }

    func addWater(_ ml: Double, context: ModelContext) async {
        let record = WaterRecord(amount: ml)
        context.insert(record)
        do {
            try context.save()
        } catch {
            return
        }
        try? await hk.saveWater(amount: ml)
        todayWaterMl += ml
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
    @State private var showQuickAdd = false
    @State private var recentlyDeletedRecord: DeletedWaterRecord?
    @State private var showUndoDelete = false

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
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddWaterSheet { ml in
                Task { await vm.addWater(ml, context: modelContext) }
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
            Image(systemName: "drop.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.waterGradient)
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

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速记录")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 10) {
                ForEach([150, 250, 350, 500], id: \.self) { ml in
                    QuickAddButton(ml: ml) {
                        Task { await vm.addWater(Double(ml), context: modelContext) }
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
                    target: "目标 10,000"
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
            Text("今日记录")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

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
        let amount = record.amount
        modelContext.delete(record)
        do {
            try modelContext.save()
            vm.todayWaterMl = max(0, vm.todayWaterMl - amount)
            showUndoDelete = true
        } catch {
            recentlyDeletedRecord = nil
        }
    }

    private func undoDelete() {
        guard let deleted = recentlyDeletedRecord else { return }
        let restored = WaterRecord(amount: deleted.amount, timestamp: deleted.timestamp, note: deleted.note)
        modelContext.insert(restored)
        do {
            try modelContext.save()
            vm.todayWaterMl += deleted.amount
            recentlyDeletedRecord = nil
            showUndoDelete = false
        } catch {
            modelContext.delete(restored)
        }
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

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.waterGradient)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(record.amount)) ml")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
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

private struct DeletedWaterRecord: Identifiable {
    let id: UUID
    let amount: Double
    let timestamp: Date
    let note: String?

    init(record: WaterRecord) {
        self.id = record.id
        self.amount = record.amount
        self.timestamp = record.timestamp
        self.note = record.note
    }
}
