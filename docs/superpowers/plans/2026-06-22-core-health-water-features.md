# Core Health Water Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add validated goal setting, local water record delete/undo, 7-day and 30-day statistics, and visible HealthKit status handling.

**Architecture:** Keep the existing SwiftUI/SwiftData app shape and add small pure Swift units for goal validation, date ranges, and statistics summaries. UI files consume those helpers directly, while `HealthKitManager` owns HealthKit availability and read status.

**Tech Stack:** SwiftUI, SwiftData, Charts, HealthKit, UserNotifications, XcodeGen, XCTest.

---

## File Structure

- Modify `project.yml`: add an `AquaLifeTests` unit test target that depends on the app target.
- Create `AquaLife/Utils/GoalSettings.swift`: clamps and validates daily water goals.
- Create `AquaLife/Utils/WaterStatsCalculator.swift`: date ranges, period selection, summary metrics, and trend classification.
- Create `AquaLifeTests/GoalSettingsTests.swift`: tests goal clamping and text parsing behavior.
- Create `AquaLifeTests/WaterStatsCalculatorTests.swift`: tests 7-day/30-day ranges, summaries, and trends.
- Modify `AquaLife/Utils/DateHelper.swift`: add a reusable `lastDays(_:)` helper.
- Modify `AquaLife/Views/Profile/ProfileView.swift`: use validated goal editing and show HealthKit status.
- Modify `AquaLife/Views/Today/TodayView.swift`: add HealthKit status banner and local delete/undo.
- Modify `AquaLife/Views/Statistics/StatsView.swift`: replace hard-coded 7-day stats with period-driven summary and chart.
- Modify `AquaLife/Services/HealthKitManager.swift`: expose status and convert read failures into visible state.
- Regenerate `AquaLife.xcodeproj` with `xcodegen generate`.

## Existing Worktree Warning

Before implementation, run:

```bash
git status --short
```

Expected current non-plan changes before this feature work:

```text
 M AquaLife.xcodeproj/project.pbxproj
 M AquaLife/Views/Statistics/StatsView.swift
?? AquaLife.xcodeproj/xcuserdata/
```

Do not revert these unless the user explicitly asks. When touching `StatsView.swift` and `project.pbxproj`, inspect the current file first and preserve unrelated user changes.

## Task 1: Add Test Target and Goal Validation

**Files:**
- Modify: `project.yml`
- Create: `AquaLife/Utils/GoalSettings.swift`
- Create: `AquaLifeTests/GoalSettingsTests.swift`
- Generated: `AquaLife.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the test target to `project.yml`**

Add this sibling target under `targets:`:

```yaml
  AquaLifeTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: AquaLifeTests
    dependencies:
      - target: AquaLife
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.zouqiwei.AquaLifeTests
```

- [ ] **Step 2: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: project generation succeeds and `AquaLife.xcodeproj/project.pbxproj` gains an `AquaLifeTests` target.

- [ ] **Step 3: Write the failing goal validation tests**

Create `AquaLifeTests/GoalSettingsTests.swift`:

```swift
import XCTest
@testable import AquaLife

final class GoalSettingsTests: XCTestCase {
    func testClampKeepsValidGoal() {
        XCTAssertEqual(GoalSettings.clamp(2200), 2200)
    }

    func testClampRoundsToNearestStepInsideRange() {
        XCTAssertEqual(GoalSettings.clamp(2249), 2200)
        XCTAssertEqual(GoalSettings.clamp(2250), 2300)
    }

    func testClampBoundsLowAndHighValues() {
        XCTAssertEqual(GoalSettings.clamp(100), 500)
        XCTAssertEqual(GoalSettings.clamp(5000), 4000)
    }

    func testParseGoalTextUsesPreviousValueForInvalidText() {
        XCTAssertEqual(GoalSettings.value(from: "abc", previous: 2100), 2100)
        XCTAssertEqual(GoalSettings.value(from: "", previous: 2100), 2100)
    }

    func testParseGoalTextClampsNumericText() {
        XCTAssertEqual(GoalSettings.value(from: " 3600 ", previous: 2000), 3600)
        XCTAssertEqual(GoalSettings.value(from: "450", previous: 2000), 500)
        XCTAssertEqual(GoalSettings.value(from: "4050", previous: 2000), 4000)
    }
}
```

- [ ] **Step 4: Run the goal tests and verify they fail**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AquaLifeTests/GoalSettingsTests
```

Expected: FAIL because `GoalSettings` does not exist. If simulator access fails because CoreSimulator is blocked by sandbox permissions, rerun the same command with escalated permissions.

- [ ] **Step 5: Implement `GoalSettings`**

Create `AquaLife/Utils/GoalSettings.swift`:

```swift
import Foundation

enum GoalSettings {
    static let minimum: Double = 500
    static let maximum: Double = 4000
    static let step: Double = 100

    static func clamp(_ value: Double) -> Double {
        let bounded = min(max(value, minimum), maximum)
        return (bounded / step).rounded() * step
    }

    static func value(from text: String, previous: Double) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue = Double(trimmed) else {
            return clamp(previous)
        }
        return clamp(rawValue)
    }
}
```

- [ ] **Step 6: Run the goal tests and verify they pass**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AquaLifeTests/GoalSettingsTests
```

Expected: PASS for all `GoalSettingsTests`.

- [ ] **Step 7: Commit Task 1**

Run:

```bash
git add project.yml AquaLife.xcodeproj/project.pbxproj AquaLife/Utils/GoalSettings.swift AquaLifeTests/GoalSettingsTests.swift
git commit -m "test: add goal validation coverage"
```

## Task 2: Add Statistics Calculator

**Files:**
- Modify: `AquaLife/Utils/DateHelper.swift`
- Create: `AquaLife/Utils/WaterStatsCalculator.swift`
- Create: `AquaLifeTests/WaterStatsCalculatorTests.swift`

- [ ] **Step 1: Write failing statistics tests**

Create `AquaLifeTests/WaterStatsCalculatorTests.swift`:

```swift
import XCTest
@testable import AquaLife

final class WaterStatsCalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testLastDaysReturnsOldestToNewestStartOfDayDates() {
        let reference = date(2026, 6, 22, hour: 15)
        let days = WaterStatsCalculator.days(for: .sevenDays, endingAt: reference, calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, date(2026, 6, 16))
        XCTAssertEqual(days.last, date(2026, 6, 22))
    }

    func testThirtyDayPeriodHasThirtyDays() {
        let days = WaterStatsCalculator.days(for: .thirtyDays, endingAt: date(2026, 6, 22), calendar: calendar)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.first, date(2026, 5, 24))
        XCTAssertEqual(days.last, date(2026, 6, 22))
    }

    func testSummaryIncludesZeroDaysInAverageAndCompletionRate() {
        let reference = date(2026, 6, 22)
        let records = [
            WaterStatsCalculator.Record(date: date(2026, 6, 16, hour: 8), amount: 2000),
            WaterStatsCalculator.Record(date: date(2026, 6, 17, hour: 9), amount: 1000),
            WaterStatsCalculator.Record(date: date(2026, 6, 17, hour: 12), amount: 1200),
        ]

        let summary = WaterStatsCalculator.summary(
            records: records,
            goal: 2000,
            period: .sevenDays,
            endingAt: reference,
            calendar: calendar
        )

        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.totalAmount, 4200)
        XCTAssertEqual(summary.reachedGoalDays, 2)
        XCTAssertEqual(summary.averageDaily, 600)
        XCTAssertEqual(summary.completionRate, 2.0 / 7.0, accuracy: 0.0001)
    }

    func testTrendClassifiesIncreasingDecreasingAndStable() {
        XCTAssertEqual(WaterStatsCalculator.trend(firstHalfAverage: 1000, secondHalfAverage: 1200), .increasing)
        XCTAssertEqual(WaterStatsCalculator.trend(firstHalfAverage: 1000, secondHalfAverage: 800), .decreasing)
        XCTAssertEqual(WaterStatsCalculator.trend(firstHalfAverage: 1000, secondHalfAverage: 1090), .stable)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour).date!
    }
}
```

- [ ] **Step 2: Run statistics tests and verify they fail**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AquaLifeTests/WaterStatsCalculatorTests
```

Expected: FAIL because `WaterStatsCalculator` does not exist.

- [ ] **Step 3: Add reusable date helper**

Modify `AquaLife/Utils/DateHelper.swift` by replacing `last7Days()` with:

```swift
    static func lastDays(_ count: Int, endingAt date: Date = .now) -> [Date] {
        guard count > 0 else { return [] }
        let end = startOfDay(date)
        return (0..<count).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: end)
        }
    }

    static func last7Days() -> [Date] {
        lastDays(7)
    }
```

- [ ] **Step 4: Implement `WaterStatsCalculator`**

Create `AquaLife/Utils/WaterStatsCalculator.swift`:

```swift
import Foundation

enum WaterStatsPeriod: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .sevenDays: return "7 天"
        case .thirtyDays: return "30 天"
        }
    }
}

enum WaterTrend: Equatable {
    case increasing
    case decreasing
    case stable

    var title: String {
        switch self {
        case .increasing: return "上升"
        case .decreasing: return "下降"
        case .stable: return "持平"
        }
    }

    var systemImage: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "minus"
        }
    }
}

enum WaterStatsCalculator {
    struct Record {
        let date: Date
        let amount: Double
    }

    struct DayAmount: Identifiable {
        let date: Date
        let amount: Double
        var id: Date { date }
    }

    struct Summary {
        let days: [DayAmount]
        let totalAmount: Double
        let reachedGoalDays: Int
        let averageDaily: Double
        let completionRate: Double
        let trend: WaterTrend
    }

    static func days(
        for period: WaterStatsPeriod,
        endingAt date: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let end = calendar.startOfDay(for: date)
        return (0..<period.rawValue).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: end)
        }
    }

    static func summary(
        records: [Record],
        goal: Double,
        period: WaterStatsPeriod,
        endingAt date: Date = .now,
        calendar: Calendar = .current
    ) -> Summary {
        let periodDays = days(for: period, endingAt: date, calendar: calendar)
        let amounts = periodDays.map { day -> DayAmount in
            let total = records
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return DayAmount(date: day, amount: total)
        }

        let total = amounts.reduce(0) { $0 + $1.amount }
        let reached = amounts.filter { $0.amount >= goal }.count
        let average = amounts.isEmpty ? 0 : total / Double(amounts.count)
        let completion = amounts.isEmpty ? 0 : Double(reached) / Double(amounts.count)
        let halfIndex = amounts.count / 2
        let firstHalf = Array(amounts.prefix(halfIndex))
        let secondHalf = Array(amounts.suffix(amounts.count - halfIndex))
        let firstAverage = averageAmount(firstHalf)
        let secondAverage = averageAmount(secondHalf)

        return Summary(
            days: amounts,
            totalAmount: total,
            reachedGoalDays: reached,
            averageDaily: average,
            completionRate: completion,
            trend: trend(firstHalfAverage: firstAverage, secondHalfAverage: secondAverage)
        )
    }

    static func trend(firstHalfAverage: Double, secondHalfAverage: Double) -> WaterTrend {
        guard firstHalfAverage > 0 else {
            return secondHalfAverage > 0 ? .increasing : .stable
        }
        if secondHalfAverage >= firstHalfAverage * 1.1 { return .increasing }
        if secondHalfAverage <= firstHalfAverage * 0.9 { return .decreasing }
        return .stable
    }

    private static func averageAmount(_ values: [DayAmount]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0) { $0 + $1.amount } / Double(values.count)
    }
}
```

- [ ] **Step 5: Run statistics tests and verify they pass**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AquaLifeTests/WaterStatsCalculatorTests
```

Expected: PASS for all `WaterStatsCalculatorTests`.

- [ ] **Step 6: Commit Task 2**

Run:

```bash
git add AquaLife/Utils/DateHelper.swift AquaLife/Utils/WaterStatsCalculator.swift AquaLifeTests/WaterStatsCalculatorTests.swift
git commit -m "feat: add water statistics calculator"
```

## Task 3: Apply Goal Validation in Profile

**Files:**
- Modify: `AquaLife/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add local goal draft state**

Inside `ProfileView`, keep `@AppStorage("dailyWaterGoal")` and replace unused `goalText` with:

```swift
    @State private var goalDraft: String = ""
```

- [ ] **Step 2: Add helper methods inside `ProfileView`**

Add these private methods:

```swift
    private func syncGoalDraft() {
        goalDraft = "\(Int(GoalSettings.clamp(dailyGoal)))"
    }

    private func commitGoalDraft() {
        let nextValue = GoalSettings.value(from: goalDraft, previous: dailyGoal)
        dailyGoal = nextValue
        goalDraft = "\(Int(nextValue))"
    }
```

- [ ] **Step 3: Replace the goal text field binding**

Replace the current `TextField("", value: $dailyGoal, formatter: NumberFormatter())` with:

```swift
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
```

- [ ] **Step 4: Clamp slider and preset updates**

Change slider to:

```swift
                            Slider(value: $dailyGoal, in: GoalSettings.minimum...GoalSettings.maximum, step: GoalSettings.step)
                                .tint(AppTheme.primary)
                                .onChange(of: dailyGoal) { _, newValue in
                                    dailyGoal = GoalSettings.clamp(newValue)
                                    syncGoalDraft()
                                }
```

Change preset button action to:

```swift
                                        dailyGoal = GoalSettings.clamp(Double(goal))
                                        syncGoalDraft()
```

- [ ] **Step 5: Initialize and commit draft on view lifecycle**

Add to the outer view:

```swift
        .onAppear {
            syncGoalDraft()
        }
        .onDisappear {
            commitGoalDraft()
        }
```

- [ ] **Step 6: Run goal tests and build**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AquaLifeTests/GoalSettingsTests
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'generic/platform=iOS Simulator'
```

Expected: tests pass and app builds.

- [ ] **Step 7: Commit Task 3**

Run:

```bash
git add AquaLife/Views/Profile/ProfileView.swift
git commit -m "feat: validate daily water goal"
```

## Task 4: Add HealthKit Status Model and UI

**Files:**
- Modify: `AquaLife/Services/HealthKitManager.swift`
- Modify: `AquaLife/Views/Today/TodayView.swift`
- Modify: `AquaLife/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add status enum to `HealthKitManager.swift`**

Add after imports:

```swift
enum HealthKitStatus: Equatable {
    case unknown
    case available
    case notAvailable
    case needsAuthorization
    case readFailed

    var title: String {
        switch self {
        case .unknown: return "等待连接"
        case .available: return "已连接"
        case .notAvailable: return "当前设备不可用"
        case .needsAuthorization: return "需要授权"
        case .readFailed: return "读取失败"
        }
    }

    var message: String {
        switch self {
        case .unknown:
            return "正在检查健康数据权限"
        case .available:
            return "健康数据可正常读取"
        case .notAvailable:
            return "当前设备不支持 HealthKit，模拟器可能无法读取健康数据"
        case .needsAuthorization:
            return "请允许 AquaLife 读取健康数据"
        case .readFailed:
            return "健康数据读取失败，可稍后重试"
        }
    }

    var needsUserAttention: Bool {
        self == .notAvailable || self == .needsAuthorization || self == .readFailed
    }
}
```

- [ ] **Step 2: Replace authorization state in `HealthKitManager`**

Replace:

```swift
    @Published var isAuthorized = false
```

with:

```swift
    @Published private(set) var status: HealthKitStatus = .unknown
```

- [ ] **Step 3: Update authorization handling**

Replace `requestAuthorization()` with:

```swift
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .notAvailable
            return false
        }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            status = .available
            return true
        } catch {
            status = .needsAuthorization
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
```

- [ ] **Step 4: Mark read failures**

In each HealthKit query completion, set `status = .readFailed` when the query error is non-nil. For example, change the `HKStatisticsQuery` closure in `fetchTodayWater()` to:

```swift
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if error != nil {
                    Task { @MainActor in self.status = .readFailed }
                    continuation.resume(returning: 0)
                    return
                }
                let total = result?.sumQuantity()?.doubleValue(for: .literUnit(with: .milli)) ?? 0
                continuation.resume(returning: total)
            }
```

Apply the same pattern to `fetchTodaySteps()`, `fetchLastNightSleep()`, `fetchLatestHeartRate()`, and `fetchWeeklyWater()`.

- [ ] **Step 5: Observe HealthKit manager in `TodayViewModel`**

Add to `TodayViewModel`:

```swift
    @Published var healthKitStatus: HealthKitStatus = .unknown
```

At the end of `loadAll()` add:

```swift
        healthKitStatus = hk.status
```

In `TodayView.task`, after requesting authorization, set status before loading:

```swift
            let _ = await HealthKitManager.shared.requestAuthorization()
            vm.healthKitStatus = HealthKitManager.shared.status
            await vm.loadAll()
```

- [ ] **Step 6: Add Today status banner**

Insert before `healthCardsSection` in the Today content stack:

```swift
                    healthKitStatusSection
```

Add this computed view in `TodayView`:

```swift
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
```

- [ ] **Step 7: Show status in Profile health section**

Add state to `ProfileView`:

```swift
    @StateObject private var healthKit = HealthKitManager.shared
```

Replace the hard-coded checkmark row in the HealthKit section with:

```swift
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
```

Keep the existing Health app button below it.

- [ ] **Step 8: Build**

Run:

```bash
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'generic/platform=iOS Simulator'
```

Expected: app builds. If Swift concurrency complains about `HealthKitManager.shared` and `@StateObject`, use `@ObservedObject private var healthKit = HealthKitManager.shared` instead.

- [ ] **Step 9: Commit Task 4**

Run:

```bash
git add AquaLife/Services/HealthKitManager.swift AquaLife/Views/Today/TodayView.swift AquaLife/Views/Profile/ProfileView.swift
git commit -m "feat: show HealthKit status"
```

## Task 5: Add Local Delete and Undo for Today Records

**Files:**
- Modify: `AquaLife/Views/Today/TodayView.swift`

- [ ] **Step 1: Add deleted record state**

Inside `TodayView`, add:

```swift
    @State private var recentlyDeletedRecord: DeletedWaterRecord?
    @State private var showUndoDelete = false
```

Add this helper struct near `WaterTimelineRow`:

```swift
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
```

- [ ] **Step 2: Add delete and undo methods**

Inside `TodayView`, add:

```swift
    private func deleteRecord(_ record: WaterRecord) {
        recentlyDeletedRecord = DeletedWaterRecord(record: record)
        modelContext.delete(record)
        do {
            try modelContext.save()
            vm.todayWaterMl = max(0, vm.todayWaterMl - record.amount)
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
```

- [ ] **Step 3: Pass delete action into rows**

Change row rendering to:

```swift
                    ForEach(todayRecords) { record in
                        WaterTimelineRow(record: record) {
                            deleteRecord(record)
                        }
                        if record.id != todayRecords.last?.id {
                            Divider().background(AppTheme.cardBorder)
                        }
                    }
```

- [ ] **Step 4: Update `WaterTimelineRow`**

Change the struct signature and body:

```swift
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
```

- [ ] **Step 5: Add undo alert**

On the outer `ZStack` or `ScrollView`, add:

```swift
        .alert("已删除本地饮水记录", isPresented: $showUndoDelete) {
            Button("撤销") { undoDelete() }
            Button("知道了", role: .cancel) {
                recentlyDeletedRecord = nil
            }
        } message: {
            Text("健康 App 中已写入的数据不会同步撤销。")
        }
```

- [ ] **Step 6: Build and manually test**

Run:

```bash
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'generic/platform=iOS Simulator'
```

Manual check:

- Add 250 ml.
- Delete that record.
- Confirm displayed Today total drops by 250 ml.
- Tap undo.
- Confirm record and displayed total return.

- [ ] **Step 7: Commit Task 5**

Run:

```bash
git add AquaLife/Views/Today/TodayView.swift
git commit -m "feat: add water record delete undo"
```

## Task 6: Upgrade Statistics UI

**Files:**
- Modify: `AquaLife/Views/Statistics/StatsView.swift`

- [ ] **Step 1: Replace local period state**

Replace:

```swift
    @State private var selectedRange = 0 // 0=7天, 1=30天
```

with:

```swift
    @State private var selectedPeriod: WaterStatsPeriod = .sevenDays
```

- [ ] **Step 2: Replace computed statistics**

Replace `last7Days`, `reachedGoalDays`, and `avgDaily` with:

```swift
    private var statsRecords: [WaterStatsCalculator.Record] {
        allRecords.map { WaterStatsCalculator.Record(date: $0.timestamp, amount: $0.amount) }
    }

    private var summary: WaterStatsCalculator.Summary {
        WaterStatsCalculator.summary(records: statsRecords, goal: dailyGoal, period: selectedPeriod)
    }
```

- [ ] **Step 3: Add period picker below header**

After the header `HStack`, add:

```swift
                    Picker("统计周期", selection: $selectedPeriod) {
                        ForEach(WaterStatsPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
```

- [ ] **Step 4: Expand summary cards**

Replace the two-card `HStack` with a `LazyVGrid`:

```swift
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
```

- [ ] **Step 5: Drive chart from selected period**

Change chart title:

```swift
                        Text("近 \(selectedPeriod.rawValue) 天")
```

Change chart data:

```swift
                            ForEach(summary.days) { item in
```

Keep the `BarMark` body the same.

- [ ] **Step 6: Run statistics tests and build**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AquaLifeTests/WaterStatsCalculatorTests
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'generic/platform=iOS Simulator'
```

Expected: statistics tests pass and app builds.

- [ ] **Step 7: Commit Task 6**

Run:

```bash
git add AquaLife/Views/Statistics/StatsView.swift
git commit -m "feat: add period water statistics"
```

## Task 7: Final Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run all unit tests**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: all tests pass. If CoreSimulator access is blocked, rerun with escalated permissions.

- [ ] **Step 2: Run app build**

Run:

```bash
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'generic/platform=iOS Simulator'
```

Expected: build succeeds.

- [ ] **Step 3: Inspect final diff**

Run:

```bash
git diff --stat HEAD
git diff --check
```

Expected: no whitespace errors. Diff should match the four approved feature areas.

- [ ] **Step 4: Manual simulator checks**

Open the app in an iOS simulator or device and verify:

- Profile goal text input clamps below 500 to 500 and above 4000 to 4000.
- Slider and presets update Today and Statistics immediately.
- Today shows HealthKit status when permission is missing or unavailable.
- Adding water creates a local record and updates total.
- Deleting a record updates total and shows undo.
- Undo restores the local record and total.
- Statistics picker switches between 7 days and 30 days.
- Summary cards show reached days, daily average, completion rate, and trend.

- [ ] **Step 5: Commit final cleanup if needed**

If verification required small fixes, commit them:

```bash
git add project.yml AquaLife.xcodeproj/project.pbxproj AquaLife/Utils/GoalSettings.swift AquaLife/Utils/WaterStatsCalculator.swift AquaLife/Utils/DateHelper.swift AquaLife/Services/HealthKitManager.swift AquaLife/Views/Profile/ProfileView.swift AquaLife/Views/Today/TodayView.swift AquaLife/Views/Statistics/StatsView.swift AquaLifeTests/GoalSettingsTests.swift AquaLifeTests/WaterStatsCalculatorTests.swift
git commit -m "fix: polish core water features"
```

If no fixes were needed, do not create an empty commit.
