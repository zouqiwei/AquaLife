import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    @Query(
        filter: #Predicate<WaterRecord> { _ in true },
        sort: \.timestamp,
        order: .reverse
    ) private var allRecords: [WaterRecord]

    @AppStorage("dailyWaterGoal") private var dailyGoal: Double = 2000
    @State private var selectedPeriod: WaterStatsPeriod = .sevenDays

    private var statsRecords: [WaterStatsCalculator.Record] {
        allRecords.map { WaterStatsCalculator.Record(date: $0.timestamp, amount: $0.effectiveAmount) }
    }

    private var summary: WaterStatsCalculator.Summary {
        WaterStatsCalculator.summary(records: statsRecords, goal: dailyGoal, period: selectedPeriod)
    }

    private var insight: WaterStatsCalculator.Insight {
        WaterStatsCalculator.insight(records: statsRecords, goal: dailyGoal, period: selectedPeriod)
    }

    private var achievement: WaterAchievement {
        WaterAchievementCalculator.achievement(records: statsRecords, goal: dailyGoal)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("饮水统计")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }

                    Picker("统计周期", selection: $selectedPeriod) {
                        ForEach(WaterStatsPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    TrendInsightCard(insight: insight)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatSummaryCard(
                            title: "\(selectedPeriod.title)达标",
                            value: "\(summary.reachedGoalDays)",
                            unit: "天",
                            icon: "checkmark.seal.fill",
                            color: AppTheme.secondary
                        )
                        StatSummaryCard(
                            title: "日均饮水",
                            value: "\(Int(summary.averageDaily))",
                            unit: "ml",
                            icon: "drop.fill",
                            color: AppTheme.primary
                        )
                        StatSummaryCard(
                            title: "达标率",
                            value: "\(Int(summary.completionRate * 100))",
                            unit: "%",
                            icon: "percent",
                            color: AppTheme.stepsColor
                        )
                        StatSummaryCard(
                            title: "趋势",
                            value: summary.trend.title,
                            unit: "",
                            icon: summary.trend.systemImage,
                            color: summary.trend == .decreasing ? AppTheme.heartColor : AppTheme.secondary
                        )
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatSummaryCard(
                            title: "连续达标",
                            value: "\(achievement.currentStreak)",
                            unit: "天",
                            icon: "flame.fill",
                            color: AppTheme.stepsColor
                        )
                        StatSummaryCard(
                            title: "最佳纪录",
                            value: "\(achievement.bestStreak)",
                            unit: "天",
                            icon: "trophy.fill",
                            color: AppTheme.secondary
                        )
                    }

                    // Bar chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("近 \(selectedPeriod.rawValue) 天")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Chart {
                            ForEach(summary.days) { item in
                                BarMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("饮水量", item.amount)
                                )
                                .foregroundStyle(
                                    item.amount >= dailyGoal
                                    ? AnyShapeStyle(AppTheme.waterGradient)
                                    : AnyShapeStyle(AppTheme.primary.opacity(0.4))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            RuleMark(y: .value("目标", dailyGoal))
                                .foregroundStyle(AppTheme.secondary.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("目标")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppTheme.secondary)
                                }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: selectedPeriod == .thirtyDays ? 5 : 1)) { _ in
                                if selectedPeriod == .thirtyDays {
                                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                                        .foregroundStyle(AppTheme.textSecondary)
                                } else {
                                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel()
                                    .foregroundStyle(AppTheme.textSecondary)
                                AxisGridLine()
                                    .foregroundStyle(AppTheme.cardBorder)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .glassCard()

                    // Calendar heatmap
                    CalendarHeatmapView(records: allRecords, goal: dailyGoal)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }
}

struct StatSummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct TrendInsightCard: View {
    let insight: WaterStatsCalculator.Insight

    private var accentColor: Color {
        switch insight.direction {
        case .improving:
            return AppTheme.secondary
        case .declining:
            return AppTheme.heartColor
        case .steady, .insufficientData:
            return AppTheme.primary
        }
    }

    private var symbol: String {
        switch insight.direction {
        case .improving:
            return "arrow.up.right.circle.fill"
        case .declining:
            return "arrow.down.right.circle.fill"
        case .steady:
            return "equal.circle.fill"
        case .insufficientData:
            return "sparkles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundColor(accentColor)
                    .frame(width: 34, height: 34)
                    .background(accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(insight.message)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(insight.action)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .glassCard()
    }
}
