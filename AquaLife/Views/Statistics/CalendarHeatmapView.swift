//
//  CalendarHeatmapView.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/23.
//

import SwiftUI

struct CalendarHeatmapView: View {
    let records: [WaterRecord]
    let goal: Double

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private let daysToShow = 35 // 5 weeks

    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<daysToShow).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func amountFor(_ date: Date) -> Double {
        records
            .filter { DateHelper.isSameDay($0.timestamp, date) }
            .reduce(0) { $0 + $1.effectiveAmount }
    }

    private func colorFor(amount: Double) -> Color {
        if amount == 0 { return AppTheme.ringTrackColor }
        let ratio = min(amount / goal, 1.0)
        if ratio >= 1.0 { return AppTheme.secondary }
        if ratio >= 0.7 { return AppTheme.primary.opacity(0.8) }
        if ratio >= 0.4 { return AppTheme.primary.opacity(0.5) }
        return AppTheme.primary.opacity(0.25)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("饮水热力图")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 4) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let amount = amountFor(day)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorFor(amount: amount))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            DateHelper.isSameDay(day, .now)
                            ? RoundedRectangle(cornerRadius: 4).stroke(AppTheme.primary, lineWidth: 1.5)
                            : nil
                        )
                }
            }

            // Legend
            HStack(spacing: 6) {
                Text("少")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
                ForEach([0.0, 0.3, 0.6, 0.85, 1.0], id: \.self) { ratio in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorFor(amount: ratio * goal + (ratio == 0 ? 0 : 1)))
                        .frame(width: 14, height: 14)
                }
                Text("多")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .glassCard()
    }
}
