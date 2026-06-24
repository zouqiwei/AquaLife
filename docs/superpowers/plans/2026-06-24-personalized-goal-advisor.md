# Personalized Goal Advisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a semi-automatic daily water goal recommendation that combines steps, sleep, and optional weather, then lets the user apply the recommendation from Today or review it in Profile.

**Architecture:** Keep recommendation logic in pure Swift helpers so the behavior stays testable and explainable. `PersonalizedGoalAdvisor` computes the recommendation, a small weather provider abstraction supplies optional temperature context, and `TodayView` / `ProfileView` render and apply the result through the existing `dailyWaterGoal` storage path.

**Tech Stack:** SwiftUI, AppStorage, HealthKit, XCTest, XcodeGen.

---

## File Structure

- Create `AquaLife/Utils/PersonalizedGoalAdvisor.swift`: pure rule engine, supporting models, refresh-threshold logic, and explanation generation.
- Create `AquaLife/Services/WeatherHydrationProvider.swift`: lightweight provider protocol and first-pass in-memory or stub-backed live provider that can return a temperature band or `nil`.
- Create `AquaLifeTests/PersonalizedGoalAdvisorTests.swift`: unit coverage for baseline, factors, clamping, partial data, and refresh thresholds.
- Modify `AquaLife/Views/Today/TodayView.swift`: load and render a recommendation card, expose an apply action, and soften the card after same-day application.
- Modify `AquaLife/Views/Profile/ProfileView.swift`: render an informational recommendation section under goal controls.
- Modify `AquaLife/Services/HealthKitManager.swift`: expose or reuse step and sleep loading in a form the recommendation flow can call without duplicating query logic.
- Modify `project.yml`: include the new test file and any new service or utility file if XcodeGen grouping needs explicit updates.
- Generated: `AquaLife.xcodeproj/project.pbxproj`.

## Current Workspace Note

Before implementation, inspect current local changes:

```bash
git status --short
```

Expected existing in-progress files include:

```text
M AquaLife/Utils/WaterIntakeAdvisor.swift
M AquaLife/Utils/WaterStatsCalculator.swift
M AquaLife/Views/Statistics/StatsView.swift
M AquaLife/Views/Today/TodayView.swift
M AquaLifeTests/WaterIntakeAdviceTests.swift
M AquaLifeTests/WaterStatsCalculatorTests.swift
```

Do not revert these. Work with the existing in-flight smart-plan changes.

### Task 1: Add Personalized Goal Rule Engine

**Files:**
- Create: `AquaLifeTests/PersonalizedGoalAdvisorTests.swift`
- Create: `AquaLife/Utils/PersonalizedGoalAdvisor.swift`

- [ ] **Step 1: Write the failing recommendation tests**

Create `AquaLifeTests/PersonalizedGoalAdvisorTests.swift`:

```swift
import XCTest
@testable import AquaLife

final class PersonalizedGoalAdvisorTests: XCTestCase {
    func testRecommendationUsesBaselineWhenNoFactorDataExists() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: nil,
                sleepMinutes: nil,
                weatherBand: nil,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2000)
        XCTAssertEqual(result.factors, [])
        XCTAssertFalse(result.shouldHighlightUpdate)
        XCTAssertTrue(result.explanation.contains("有限"))
    }

    func testRecommendationAddsStepSleepAndWeatherAdjustments() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 12500,
                sleepMinutes: 320,
                weatherBand: .hot,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2700)
        XCTAssertEqual(result.factors.map(\.kind), [.activity, .recovery, .weather])
        XCTAssertTrue(result.explanation.contains("较热"))
    }

    func testRecommendationClampsThroughGoalSettings() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 3800,
                stepCount: 18000,
                sleepMinutes: 250,
                weatherBand: .hot,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 4000)
    }

    func testRecommendationHighlightsMeaningfulRefreshOnly() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 8100,
                sleepMinutes: 430,
                weatherBand: .mild,
                previousRecommendedGoal: 2100,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2200)
        XCTAssertTrue(result.shouldHighlightUpdate)
    }

    func testRecommendationDoesNotHighlightSameGoalAgain() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 7900,
                sleepMinutes: 430,
                weatherBand: .mild,
                previousRecommendedGoal: 2100,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2100)
        XCTAssertFalse(result.shouldHighlightUpdate)
    }

    private var fixedDate: Date {
        DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 24, hour: 9).date!
    }
}
```

- [ ] **Step 2: Run the new recommendation tests and verify they fail**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,id=07220BB4-CAD1-4213-BDF1-7790A35ADCBA' -only-testing:AquaLifeTests/PersonalizedGoalAdvisorTests
```

Expected: FAIL because `PersonalizedGoalAdvisor`, `PersonalizedGoalInput`, and `WeatherHydrationBand` do not exist yet.

- [ ] **Step 3: Implement the pure recommendation engine**

Create `AquaLife/Utils/PersonalizedGoalAdvisor.swift`:

```swift
import Foundation

enum WeatherHydrationBand: Equatable {
    case cool
    case mild
    case warm
    case hot
}

enum PersonalizedGoalFactorKind: Equatable {
    case activity
    case recovery
    case weather
}

struct PersonalizedGoalFactor: Equatable {
    let kind: PersonalizedGoalFactorKind
    let delta: Double
    let summary: String
}

struct PersonalizedGoalInput {
    let baselineGoal: Double
    let stepCount: Int?
    let sleepMinutes: Int?
    let weatherBand: WeatherHydrationBand?
    let previousRecommendedGoal: Double?
    let now: Date
}

struct PersonalizedGoalRecommendation: Equatable {
    let goal: Double
    let factors: [PersonalizedGoalFactor]
    let explanation: String
    let shouldHighlightUpdate: Bool
}

enum PersonalizedGoalAdvisor {
    static func recommendation(input: PersonalizedGoalInput) -> PersonalizedGoalRecommendation {
        var factors: [PersonalizedGoalFactor] = []

        if let stepFactor = activityFactor(for: input.stepCount) {
            factors.append(stepFactor)
        }
        if let sleepFactor = recoveryFactor(for: input.sleepMinutes) {
            factors.append(sleepFactor)
        }
        if let weatherFactor = weatherFactor(for: input.weatherBand) {
            factors.append(weatherFactor)
        }

        let adjustedGoal = GoalSettings.clamp(input.baselineGoal + factors.reduce(0) { $0 + $1.delta })
        let previous = input.previousRecommendedGoal ?? adjustedGoal
        let shouldHighlight = abs(adjustedGoal - previous) >= GoalSettings.step && adjustedGoal != previous

        return PersonalizedGoalRecommendation(
            goal: adjustedGoal,
            factors: factors,
            explanation: explanation(for: factors, baselineGoal: input.baselineGoal, recommendedGoal: adjustedGoal),
            shouldHighlightUpdate: shouldHighlight
        )
    }

    static func activityFactor(for steps: Int?) -> PersonalizedGoalFactor? {
        guard let steps else { return nil }
        let delta: Double
        switch steps {
        case ..<4000: delta = 0
        case 4000..<8000: delta = 100
        case 8000..<12000: delta = 200
        case 12000..<16000: delta = 300
        default: delta = 400
        }
        guard delta > 0 else { return nil }
        return PersonalizedGoalFactor(kind: .activity, delta: delta, summary: "今天活动量偏高")
    }

    static func recoveryFactor(for sleepMinutes: Int?) -> PersonalizedGoalFactor? {
        guard let sleepMinutes else { return nil }
        let delta: Double
        switch sleepMinutes {
        case 480...: delta = 0
        case 360..<480: delta = 100
        default: delta = 200
        }
        guard delta > 0 else { return nil }
        return PersonalizedGoalFactor(kind: .recovery, delta: delta, summary: "昨晚睡眠偏少")
    }

    static func weatherFactor(for band: WeatherHydrationBand?) -> PersonalizedGoalFactor? {
        guard let band else { return nil }
        let delta: Double
        let summary: String
        switch band {
        case .cool, .mild:
            delta = 0
            summary = ""
        case .warm:
            delta = 100
            summary = "今天偏暖"
        case .hot:
            delta = 200
            summary = "今天较热"
        }
        guard delta > 0 else { return nil }
        return PersonalizedGoalFactor(kind: .weather, delta: delta, summary: summary)
    }

    private static func explanation(
        for factors: [PersonalizedGoalFactor],
        baselineGoal: Double,
        recommendedGoal: Double
    ) -> String {
        guard !factors.isEmpty else {
            return "今天可用数据有限，先按当前目标 \(Int(baselineGoal)) ml 保持稳定节奏。"
        }
        let reasons = factors.map(\.summary).joined(separator: "，")
        return "\(reasons)，建议把今日目标调整到 \(Int(recommendedGoal)) ml。"
    }
}
```

- [ ] **Step 4: Run the new recommendation tests and verify they pass**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,id=07220BB4-CAD1-4213-BDF1-7790A35ADCBA' -only-testing:AquaLifeTests/PersonalizedGoalAdvisorTests
```

Expected: PASS for all `PersonalizedGoalAdvisorTests`.

- [ ] **Step 5: Commit Task 1**

Run:

```bash
git add AquaLife/Utils/PersonalizedGoalAdvisor.swift AquaLifeTests/PersonalizedGoalAdvisorTests.swift
git commit -m "feat: add personalized goal advisor"
```

### Task 2: Add Weather Provider Abstraction

**Files:**
- Create: `AquaLife/Services/WeatherHydrationProvider.swift`
- Test: `AquaLifeTests/PersonalizedGoalAdvisorTests.swift`

- [ ] **Step 1: Add the provider abstraction**

Create `AquaLife/Services/WeatherHydrationProvider.swift`:

```swift
import Foundation

protocol WeatherHydrationProviding {
    func currentBand() async -> WeatherHydrationBand?
}

actor WeatherHydrationProvider: WeatherHydrationProviding {
    static let shared = WeatherHydrationProvider()

    func currentBand() async -> WeatherHydrationBand? {
        nil
    }
}
```

- [ ] **Step 2: Verify the project still builds**

Run:

```bash
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,id=07220BB4-CAD1-4213-BDF1-7790A35ADCBA'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit Task 2**

Run:

```bash
git add AquaLife/Services/WeatherHydrationProvider.swift
git commit -m "feat: add weather hydration provider abstraction"
```

### Task 3: Surface Recommendation Data in Today

**Files:**
- Modify: `AquaLife/Views/Today/TodayView.swift`
- Modify: `AquaLife/Services/HealthKitManager.swift`
- Modify: `AquaLife/Utils/PersonalizedGoalAdvisor.swift`

- [ ] **Step 1: Add a lightweight recommendation state to `TodayViewModel`**

Add stored state and loader shape inside `TodayViewModel`:

```swift
    @Published var personalizedGoal: PersonalizedGoalRecommendation?
    @Published var personalizedGoalAppliedToday = false

    func refreshPersonalizedGoal(
        baselineGoal: Double,
        weatherProvider: WeatherHydrationProviding = WeatherHydrationProvider.shared
    ) async {
        let weatherBand = await weatherProvider.currentBand()
        let recommendation = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: baselineGoal,
                stepCount: stepCount,
                sleepMinutes: sleepMinutes,
                weatherBand: weatherBand,
                previousRecommendedGoal: personalizedGoal?.goal,
                now: .now
            )
        )
        personalizedGoal = recommendation
    }
```

- [ ] **Step 2: Call the recommendation refresh after health data loads**

Update `TodayView` task flow:

```swift
        .task {
            let _ = await HealthKitManager.shared.requestAuthorization()
            vm.healthKitStatus = HealthKitManager.shared.status
            await vm.loadAll()
            await vm.refreshPersonalizedGoal(baselineGoal: dailyGoal)
        }
```

- [ ] **Step 3: Add a recommendation card below the smart advice card**

Add a `personalizedGoalSection` in `TodayView`:

```swift
    @ViewBuilder
    private var personalizedGoalSection: some View {
        if let recommendation = vm.personalizedGoal {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日建议目标")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("\(Int(recommendation.goal)) ml")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                    Spacer()
                    if vm.personalizedGoalAppliedToday {
                        Text("已应用")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.secondary)
                    } else {
                        Button("应用建议") {
                            dailyGoal = recommendation.goal
                            vm.personalizedGoalAppliedToday = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Text(recommendation.explanation)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .glassCard()
        }
    }
```

Insert it into the `VStack` after `smartAdviceSection`.

- [ ] **Step 4: Recompute after applying a recommendation**

After `dailyGoal = recommendation.goal`, trigger:

```swift
Task { await vm.refreshPersonalizedGoal(baselineGoal: dailyGoal) }
```

Expected: the CTA quiets down and the new baseline is reflected.

- [ ] **Step 5: Run focused build verification**

Run:

```bash
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,id=07220BB4-CAD1-4213-BDF1-7790A35ADCBA'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit Task 3**

Run:

```bash
git add AquaLife/Views/Today/TodayView.swift AquaLife/Services/HealthKitManager.swift
git commit -m "feat: surface personalized goal in today view"
```

### Task 4: Explain Recommendation in Profile

**Files:**
- Modify: `AquaLife/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add local recommendation state to `ProfileView`**

Add state:

```swift
    @State private var personalizedGoal: PersonalizedGoalRecommendation?
```

- [ ] **Step 2: Load a lightweight recommendation on appear**

Add:

```swift
        .task {
            let weatherBand = await WeatherHydrationProvider.shared.currentBand()
            personalizedGoal = PersonalizedGoalAdvisor.recommendation(
                input: PersonalizedGoalInput(
                    baselineGoal: dailyGoal,
                    stepCount: 0,
                    sleepMinutes: nil,
                    weatherBand: weatherBand,
                    previousRecommendedGoal: nil,
                    now: .now
                )
            )
        }
```

This first pass keeps Profile informational even before deeper shared-state wiring.

- [ ] **Step 3: Add a personalized recommendation section under goal controls**

Insert inside the water goal `SettingsSection` after presets:

```swift
                            if let personalizedGoal {
                                Divider().background(AppTheme.cardBorder)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("今日个性化建议 \(Int(personalizedGoal.goal)) ml")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(personalizedGoal.explanation)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
```

- [ ] **Step 4: Build again to confirm Profile compiles cleanly**

Run:

```bash
xcodebuild build -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,id=07220BB4-CAD1-4213-BDF1-7790A35ADCBA'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit Task 4**

Run:

```bash
git add AquaLife/Views/Profile/ProfileView.swift
git commit -m "feat: show personalized goal context in profile"
```

### Task 5: Regenerate Project and Run Full Verification

**Files:**
- Modify: `project.yml`
- Generated: `AquaLife.xcodeproj/project.pbxproj`

- [ ] **Step 1: Regenerate the Xcode project if file lists changed**

Run:

```bash
xcodegen generate
```

Expected: project generation succeeds and includes the new utility, service, test, and plist files.

- [ ] **Step 2: Run the full test suite**

Run:

```bash
xcodebuild test -project AquaLife.xcodeproj -scheme AquaLife -destination 'platform=iOS Simulator,id=07220BB4-CAD1-4213-BDF1-7790A35ADCBA'
```

Expected: all `AquaLifeTests` pass. If simulator runner flakes again, rerun once and capture the named failing test if any.

- [ ] **Step 3: Manual verification checklist**

Verify in the app:

```text
1. Today shows a personalized goal card with an apply action.
2. Applying the recommendation updates the progress target immediately.
3. Profile shows the recommendation explanation below the goal controls.
4. The feature still shows a result when weather is unavailable.
```

- [ ] **Step 4: Commit Task 5**

Run:

```bash
git add project.yml AquaLife.xcodeproj/project.pbxproj AquaLifeTests/Info.plist AquaLife/Services/WeatherHydrationProvider.swift AquaLife/Utils/PersonalizedGoalAdvisor.swift AquaLife/Views/Today/TodayView.swift AquaLife/Views/Profile/ProfileView.swift AquaLifeTests/PersonalizedGoalAdvisorTests.swift
git commit -m "feat: add personalized goal recommendation flow"
```

## Self-Review

- Spec coverage: the plan covers the rule engine, missing-data degradation, Today apply flow, Profile explanation, thresholded refresh logic, and verification.
- Placeholder scan: all tasks name concrete files, commands, and expected outcomes.
- Type consistency: `PersonalizedGoalInput`, `PersonalizedGoalRecommendation`, `PersonalizedGoalFactor`, and `WeatherHydrationBand` are introduced once and reused consistently across tasks.
