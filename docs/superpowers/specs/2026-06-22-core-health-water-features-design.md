# AquaLife Core Health and Water Features Design

## Scope

This feature package completes four core AquaLife workflows:

1. Editable daily water goal that updates Today and Statistics views.
2. Local water record deletion with undo.
3. Stronger 7-day and 30-day statistics.
4. Clear HealthKit availability, authorization, and failure states.

The implementation should extend the existing SwiftUI and SwiftData structure rather than introduce a broad architecture rewrite.

## Existing Context

- `ProfileView` already stores `dailyWaterGoal` in `@AppStorage` and exposes a text field, slider, and preset buttons.
- `TodayView` reads `dailyWaterGoal`, shows progress, records local `WaterRecord` objects, and writes new water samples to HealthKit.
- `StatsView` calculates the last 7 days from local `WaterRecord` data. It has an unused `StatsViewModel` that fetches HealthKit weekly water data.
- `HealthKitManager` requests authorization and fetches water, steps, sleep, and heart rate, but currently exposes only a Boolean authorization flag and mostly ignores query errors.

## Product Decisions

- Statistics use local SwiftData `WaterRecord` data as the source of truth.
- Adding water continues to write to both SwiftData and HealthKit when possible.
- Deleting or undoing a local record does not delete or recreate HealthKit samples.
- HealthKit state should be visible to users instead of silently failing or pretending to be connected.
- The feature package should not require data migration.

## Goal Setting

`ProfileView` will keep the current goal controls and add validation:

- Supported goal range: `500...4000 ml`.
- Step size: `100 ml`.
- Text input values outside the range are clamped when committed.
- Invalid text input falls back to the previous valid value.
- Presets remain `1500`, `2000`, `2500`, and `3000`.

The goal remains stored in `@AppStorage("dailyWaterGoal")` so `TodayView` and `StatsView` update automatically.

## Water Record Management

`TodayView` will support deleting records from the "今日记录" section.

Behavior:

- Each row exposes a deletion action using a compact row control or native SwiftUI swipe action, depending on which fits the existing custom card layout best.
- Deleting removes the record from SwiftData and immediately updates the Today progress.
- After deletion, the user sees an undo affordance.
- Undo reinserts a local `WaterRecord` with the same amount, timestamp, and note.
- Undo does not write a new HealthKit sample.
- Deletion copy should make the HealthKit limitation clear in concise language.

The implementation should avoid relying on HealthKit sample identifiers because existing `WaterRecord` objects do not store them.

## Statistics Enhancement

`StatsView` will add period switching between 7 days and 30 days.

The selected period drives:

- Bar chart data.
- Reached-goal days.
- Average daily water intake.
- Goal completion rate.
- Trend summary.

Statistics definitions:

- `reachedGoalDays`: days in the selected period where total local intake is greater than or equal to the current goal.
- `avgDaily`: total intake divided by the selected period length, including zero-intake days.
- `completionRate`: `reachedGoalDays / periodDays`.
- `trend`: compare average intake in the first half of the selected period with average intake in the second half.
  - Increase if second-half average is at least 10% higher.
  - Decrease if second-half average is at least 10% lower.
  - Stable otherwise.

`CalendarHeatmapView` remains a recent 35-day overview and should continue using the current goal for color intensity.

## HealthKit Status

`HealthKitManager` will expose a clearer status model. Required states:

- `available`: HealthKit is available and authorization request completed.
- `notAvailable`: HealthKit is not available on the current device.
- `needsAuthorization`: HealthKit authorization has not been granted or cannot be confirmed.
- `readFailed`: one or more reads failed after authorization.

The manager should preserve enough detail for user-facing messages without leaking technical errors into the UI.

UI placement:

- `TodayView` shows a compact status banner above health metric cards when HealthKit is unavailable, unauthorized, or read failed.
- `ProfileView` shows the current HealthKit status in the "健康数据" section.
- `ProfileView` provides a retry authorization action and keeps the existing Health app link.

On simulator or unsupported devices, the UI should state that health data is unavailable on the current device.

## Error Handling

- HealthKit authorization failures should update status and keep the app usable.
- HealthKit read failures should not block local water tracking.
- Water additions should still save locally if HealthKit write fails.
- If local SwiftData save fails during add, delete, or undo, the UI should avoid showing success.

## Testing

Use TDD for implementation changes where practical.

Suggested testable units:

- Daily goal validation helper.
- Date range generation for 7-day and 30-day periods.
- Statistics summary calculation.
- Trend classification.
- Local delete and undo logic if extracted into a small helper or view model.

Manual verification:

- Changing goal in Profile updates Today progress and Stats summaries.
- Deleting a record reduces today's total.
- Undo restores the record and total.
- 7-day and 30-day stats switch without layout issues.
- HealthKit unavailable or unauthorized states show user-facing messages.

## Out of Scope

- HealthKit sample deletion.
- Sync reconciliation between local records and HealthKit water history.
- Data migration for existing records.
- Reminder schedule changes.
- Broad state-management refactor.
