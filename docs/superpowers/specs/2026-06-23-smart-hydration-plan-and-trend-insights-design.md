# AquaLife Smart Hydration Plan and Trend Insights Design

## Scope

This feature package adds two linked experiences:

1. A smart hydration plan on the Today screen that tells the user when to drink next and how much to drink.
2. A trend insight card on the Statistics screen that summarizes recent progress and points out one actionable weak period.

The work should extend the existing SwiftUI, SwiftData, and AppStorage structure without introducing a new app-wide state layer.

## Existing Context

- `TodayView` already shows a progress ring, quick add actions, and a short hydration advice card powered by `WaterIntakeAdvisor`.
- `ProfileView` already stores reminder start and end hours in `@AppStorage`.
- `ReminderSchedule` already calculates valid reminder hours from an interval and active time window.
- `StatsView` already computes period summaries through `WaterStatsCalculator` and shows 7-day and 30-day views.
- `WaterRecord` stores timestamp, amount, drink type, and effective hydration amount.

## Product Decisions

- The smart plan follows the user's configured reminder time window.
- Reminder enablement only affects notifications; it does not disable the Today recommendation.
- The Today screen should show one compact action-focused recommendation rather than a large multi-step planner.
- The Statistics screen should show a fuller natural-language insight that combines trend, weak time window, and a simple suggestion.
- All calculations use local SwiftData `WaterRecord` data as the source of truth.

## Smart Hydration Plan

`WaterIntakeAdvisor` will evolve from a pace-only helper into a small planning helper.

Inputs:

- Current effective intake.
- Daily goal.
- Current date and time.
- Reminder start hour.
- Reminder end hour.

Outputs:

- Existing progress status (`completed`, `onTrack`, `behind`).
- Expected progress for the current time window.
- Remaining intake.
- Recommended serving count.
- Next suggested drink time.
- Next suggested drink amount.
- A compact progress snapshot for the active time window.

Planning rules:

- The active hydration window is the configured reminder start and end hours.
- Before the start hour, the next suggestion anchors to the start hour.
- After the end hour:
  - If the goal is reached, the plan stays in `completed`.
  - If the goal is not reached, the plan suggests a final small catch-up action immediately rather than inventing future hours outside the window.
- Suggested amount stays in a comfortable range of `200...350 ml`.
- If the user is meaningfully behind pace, suggested amount leans upward within that range.
- If the user is close to goal, suggested amount leans downward.
- Suggested time is based on splitting the remaining active window into the remaining serving count, with the next time never earlier than the current time rounded forward to a practical boundary.

Today UI:

- Keep the existing advice card position below the progress ring.
- Replace the current generic copy with:
  - Title state.
  - A short message.
  - A highlighted row for `下一杯 HH:mm · XXX ml`.
  - A subtle progress strip showing completed versus remaining suggested servings when not completed.
- When completed, the card should gracefully fall back to a short maintenance message without the next-cup row.

## Trend Insights

`WaterStatsCalculator` will gain insight generation for the currently selected period.

Inputs:

- Daily aggregated effective intake for the selected period.
- Current goal.
- All local records in the selected period, including timestamps.

Outputs:

- Existing summary metrics.
- A new trend insight model containing:
  - Headline.
  - Supporting sentence.
  - Weak time window label.
  - Suggested next action sentence.
  - Direction marker (`improving`, `declining`, `steady`, `insufficientData`).

Insight rules:

- Use the selected period (`7` or `30` days).
- Keep the current trend definition based on first-half versus second-half average.
- Calculate weak time window by grouping records into practical buckets:
  - Morning: `start..<12`
  - Afternoon: `12..<18`
  - Evening: `18...end`
- Find the bucket with the lowest average contribution on days with any intake history in the selected period.
- Generate concise natural-language copy:
  - Improving example: higher than earlier period, plus weakest bucket.
  - Declining example: lower than earlier period, plus weakest bucket.
  - Steady example: stable pace, plus weakest bucket.
  - Sparse-data example: emphasize building consistency first.

Statistics UI:

- Add a featured insight card near the top of `StatsView`, above the summary grid.
- The card should read like product guidance, not analytics jargon.
- Keep the existing chart and metric cards unchanged unless minor spacing updates are needed.

## Error Handling

- Invalid reminder windows already collapse to an empty schedule; the planning helper should fall back to a default `8...22` active window when start and end are not usable for planning.
- Empty or sparse record sets should produce a calm fallback insight rather than misleading trend claims.
- The Today screen should never hide existing water tracking actions because planning data is unavailable.

## Testing

Add or extend unit tests for:

- Planning within the configured time window.
- Before-start and after-end plan behavior.
- Suggested amount clamping to the comfort range.
- Insight generation for improving, declining, steady, and sparse data cases.
- Weak time window detection.

Manual verification:

- Change reminder hours in `ProfileView` and confirm the Today recommendation follows the new window even when reminders are disabled.
- Add water during the day and confirm the next-cup recommendation updates.
- Switch `StatsView` between 7-day and 30-day periods and confirm the insight copy updates with the period.

## Out of Scope

- Notification copy personalization based on the smart plan.
- Editing reminder interval behavior.
- Historical push notification analysis.
- HealthKit-driven hydration planning.
