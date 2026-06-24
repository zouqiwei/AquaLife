# Smart Hydration Plan and Trend Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Today recommendation that follows the user's hydration window and a Statistics insight card that turns recent intake patterns into actionable guidance.

**Architecture:** Extend the existing pure helpers instead of creating view models for every screen. `WaterIntakeAdvisor` owns next-cup planning, `WaterStatsCalculator` owns insight generation, and `TodayView` and `StatsView` render the new data directly from those helpers.

**Tech Stack:** SwiftUI, SwiftData, Charts, AppStorage, XCTest.

---

## File Structure

- Modify `AquaLife/Utils/WaterIntakeAdvisor.swift`: add planning inputs, next-cup recommendation, and serving progress data.
- Modify `AquaLifeTests/WaterIntakeAdviceTests.swift`: add failing tests for reminder-window planning behavior.
- Modify `AquaLife/Utils/WaterStatsCalculator.swift`: add weak-window analysis and natural-language trend insight generation.
- Modify `AquaLifeTests/WaterStatsCalculatorTests.swift`: add failing tests for insight generation and weak-window detection.
- Modify `AquaLife/Views/Today/TodayView.swift`: render the compact next-cup plan card.
- Modify `AquaLife/Views/Statistics/StatsView.swift`: render the featured insight card above summary metrics.

## Task 1: Extend Hydration Planning Logic

**Files:**
- Modify: `AquaLifeTests/WaterIntakeAdviceTests.swift`
- Modify: `AquaLife/Utils/WaterIntakeAdvisor.swift`

- [ ] **Step 1: Write the failing planning tests**
- [ ] **Step 2: Run the hydration advice tests and verify the new cases fail**
- [ ] **Step 3: Implement next-cup planning and serving progress in `WaterIntakeAdvisor`**
- [ ] **Step 4: Run the hydration advice tests and verify they pass**

## Task 2: Add Trend Insight Generation

**Files:**
- Modify: `AquaLifeTests/WaterStatsCalculatorTests.swift`
- Modify: `AquaLife/Utils/WaterStatsCalculator.swift`

- [ ] **Step 1: Write the failing insight tests**
- [ ] **Step 2: Run the statistics tests and verify the new cases fail**
- [ ] **Step 3: Implement weak-window analysis and natural-language insights**
- [ ] **Step 4: Run the statistics tests and verify they pass**

## Task 3: Hook the Today Screen to the New Plan

**Files:**
- Modify: `AquaLife/Views/Today/TodayView.swift`

- [ ] **Step 1: Update the smart advice section to read reminder hours from `@AppStorage`**
- [ ] **Step 2: Render the next-cup row and serving progress strip**
- [ ] **Step 3: Keep completed-state messaging compact and calm**
- [ ] **Step 4: Build and run focused tests to ensure the screen compiles with the new advisor API**

## Task 4: Hook the Statistics Screen to the New Insight

**Files:**
- Modify: `AquaLife/Views/Statistics/StatsView.swift`

- [ ] **Step 1: Compute the selected-period insight from `WaterStatsCalculator`**
- [ ] **Step 2: Add a featured insight card above the summary grid**
- [ ] **Step 3: Keep the rest of the statistics layout intact apart from spacing adjustments**
- [ ] **Step 4: Run the full AquaLife test target**

## Self-Review

- Spec coverage: the plan covers window-aware planning, compact Today rendering, featured Stats insight rendering, and helper-level tests.
- Placeholder scan: no `TODO` or deferred behavior remains.
- Type consistency: `WaterIntakeAdvisor` and `WaterStatsCalculator` remain the single sources for the new computed models.
