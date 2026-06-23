import SwiftUI
import SwiftData

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitItem.sortOrder) private var habits: [HabitItem]
    @Query(sort: \CheckInRecord.date) private var allCheckIns: [CheckInRecord]

    private var todayCheckIns: [UUID] {
        allCheckIns
            .filter { DateHelper.isSameDay($0.date, .now) }
            .map { $0.habitId }
    }

    private func isChecked(_ habit: HabitItem) -> Bool {
        todayCheckIns.contains(habit.id)
    }

    private func toggle(_ habit: HabitItem) {
        if isChecked(habit) {
            // Remove
            if let record = allCheckIns.first(where: {
                $0.habitId == habit.id && DateHelper.isSameDay($0.date, .now)
            }) {
                modelContext.delete(record)
            }
        } else {
            let record = CheckInRecord(habitId: habit.id)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func streak(for habit: HabitItem) -> Int {
        var count = 0
        var day = Calendar.current.startOfDay(for: Date())
        while true {
            let checked = allCheckIns.contains {
                $0.habitId == habit.id && DateHelper.isSameDay($0.date, day)
            }
            if !checked { break }
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("健康打卡")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("\(todayCheckIns.count) / \(habits.count) 完成")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()

                        // Progress circle (small)
                        ZStack {
                            Circle()
                                .stroke(AppTheme.ringTrackColor, lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: habits.isEmpty ? 0 : Double(todayCheckIns.count) / Double(habits.count))
                                .stroke(AppTheme.secondary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 44, height: 44)
                    }

                    // Habit list
                    if habits.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(habits) { habit in
                                HabitRowView(
                                    habit: habit,
                                    isChecked: isChecked(habit),
                                    streak: streak(for: habit),
                                    onToggle: { toggle(habit) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if habits.isEmpty { seedDefaultHabits() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textSecondary)
            Text("还没有打卡习惯")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func seedDefaultHabits() {
        for habit in HabitItem.defaults {
            modelContext.insert(habit)
        }
        try? modelContext.save()
    }
}

struct HabitRowView: View {
    let habit: HabitItem
    let isChecked: Bool
    let streak: Int
    let onToggle: () -> Void

    @State private var scale: CGFloat = 1.0

    private var color: Color {
        Color(hex: habit.colorHex)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: habit.icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Name + streak
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("连续 \(streak) 天")
                            .font(.system(size: 12))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                } else {
                    Text("今天开始打卡吧")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Checkmark button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring()) { scale = 1.0 }
                }
                onToggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(isChecked ? color : color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(scale)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassCard()
    }
}
