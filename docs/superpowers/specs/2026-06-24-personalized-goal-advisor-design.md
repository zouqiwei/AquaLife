# AquaLife Personalized Goal Advisor Design

## Scope

This feature package adds a semi-automatic personalized water goal recommendation.

Each day, AquaLife will generate a suggested goal using:

1. Activity level from step count.
2. Recovery context from last-night sleep.
3. Weather or temperature context when available.

The user remains in control. The app suggests a goal and provides a one-tap way to apply it, but it does not automatically overwrite the stored daily goal.

## Existing Context

- `ProfileView` already owns `dailyWaterGoal` editing through `@AppStorage`.
- `TodayView` already reads the stored goal and uses it for progress and advice.
- `StatsView` already updates from `dailyWaterGoal`.
- `HealthKitManager` already fetches step count and sleep data for the Today experience.
- Goal validation is already centralized in `GoalSettings`.
- The project currently has no dedicated weather data service or weather permission flow.

## Product Decisions

- Personalized goals are advisory, not automatic.
- A recommendation is generated each morning and can refresh lightly during the day when activity or weather changes enough to matter.
- Applying the suggestion updates the current app goal through the existing `dailyWaterGoal` storage path.
- The app should explain why a recommendation changed in plain product language.
- Missing data should degrade gracefully instead of hiding the feature.

## Recommendation Model

The recommendation will use a layered rule model rather than a black-box score.

Flow:

1. Start from the current stored goal as the baseline.
2. Apply an activity adjustment from today's step count.
3. Apply a recovery adjustment from last-night sleep duration.
4. Apply a weather adjustment from temperature or a simplified heat band.
5. Clamp the result through `GoalSettings` so the output remains within the supported range and step size.

The helper should expose both the final recommendation and the per-factor contributions so the UI can explain the result clearly.

## Factor Rules

### Activity Adjustment

Use step-count bands so the recommendation is stable and easy to test.

Suggested first-pass bands:

- `< 4,000` steps: `0 ml`
- `4,000..<8,000`: `+100 ml`
- `8,000..<12,000`: `+200 ml`
- `12,000..<16,000`: `+300 ml`
- `>= 16,000`: `+400 ml`

The recommendation can refresh during the day if the user crosses into a higher band.

### Sleep Adjustment

Use last-night sleep as a small recovery nudge rather than a dominant factor.

Suggested first-pass bands:

- `>= 8h`: `0 ml`
- `6h..<8h`: `+100 ml`
- `< 6h`: `+200 ml`

This factor should stay modest so the suggestion remains believable.

### Weather Adjustment

Weather is optional and should plug into the system through a small provider abstraction.

Suggested first-pass bands:

- Cool or mild day: `0 ml`
- Warm day: `+100 ml`
- Hot day: `+200 ml`

If weather data is unavailable, the recommendation still works using steps and sleep only.

## Refresh Strategy

The system should generate a recommendation:

- On first app load of the day.
- When fresh health data is loaded.
- When weather data changes enough to move to another weather band.
- When step count crosses into a new activity band.

To avoid jitter:

- Do not refresh the visible recommendation for very small changes.
- Only surface an updated recommendation when the newly computed goal differs from the current recommendation by at least `100 ml`.

## UI Placement

### Today Screen

Add a compact recommendation card near the existing progress/advice area.

The card should show:

- Recommended goal for today.
- One-sentence explanation.
- A primary action: `应用建议`.
- A secondary quiet state once the suggestion has already been applied today.

This is the main action surface for the feature.

### Profile Screen

Add a secondary informational section below the current goal controls.

The section should show:

- Latest personalized recommendation.
- Which factors contributed today.
- A lightweight explanation when weather data is unavailable.

This gives users context without forcing them to act from settings.

## Data and Architecture

Add a new pure helper, tentatively `PersonalizedGoalAdvisor`, responsible for:

- Computing the recommended goal.
- Returning structured contribution data.
- Returning explanation copy inputs or derived explanation strings.
- Determining whether the suggestion meaningfully changed.

Recommended supporting types:

- `PersonalizedGoalInput`
- `PersonalizedGoalRecommendation`
- `PersonalizedGoalFactor`
- `WeatherHydrationBand`

Weather should be accessed through a thin provider interface so the rule engine stays testable and independent from network or platform APIs.

First-pass integration can store the latest recommendation in view state rather than introducing a new persistence model.

## Missing Data Behavior

- No steps available: use baseline + sleep + weather.
- No sleep available: use baseline + steps + weather.
- No weather available: use baseline + steps + sleep.
- No factor data available: return the baseline goal and explain that today's recommendation is based on limited context.

The feature should always produce a result.

## Apply Behavior

When the user taps `应用建议`:

- Update `dailyWaterGoal` through the existing `@AppStorage` path.
- Update any relevant visible UI immediately in Today and Statistics.
- Mark the recommendation as applied for the current day so the CTA can soften instead of repeatedly nudging.

Applying a suggestion should not permanently disable future recommendations. A new day can produce a fresh suggested goal.

## Error Handling

- Health data fetch failures should leave the last usable recommendation in place when possible.
- Weather lookup failures should not surface raw technical errors in the main UI.
- If the recommendation cannot be refreshed, the app should remain fully usable with the stored manual goal.

## Testing

Unit tests should cover:

- Baseline-only recommendation.
- Step-band adjustments.
- Sleep-band adjustments.
- Weather-band adjustments.
- Combined-factor recommendation.
- Goal clamping through `GoalSettings`.
- Recommendation refresh threshold behavior.
- Explanation output when data is partially missing.

Manual verification should cover:

- Today card appears with a recommendation and one-tap apply action.
- Applying the suggestion updates Today and Stats immediately.
- Profile explains the recommendation source factors.
- Missing weather data still shows a sensible recommendation.
- A new day produces a fresh recommendation.

## Out of Scope

- Fully automatic daily goal changes.
- Historical machine-learning personalization.
- Weight, caffeine, or workout-type based adjustments.
- Remote sync or backend-stored recommendation history.
