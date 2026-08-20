# 0201 — Switch compact headers before space is exhausted

Date: 2026-08-18

## Symptom

After the Mac Planner gained current-value menu fallbacks, a narrow Week layout still showed every expanded segmented control and the textual `Go to date` button reached the clipped trailing edge.

## Root Cause

The header switched to compact controls only when the measured regular row was wider than the available width. A row with almost no remaining width therefore counted as fitting even though native control sizing and the trailing boundary left no usable breathing room.

## Fix

The regular header now requires 120 points of spare width beyond its measured controls. Below that reserve it switches all choice controls to current-value menus and makes `Go to date` icon-only before the row reaches the trailing edge.

## Prevention Rule

Do not use zero-overflow as the breakpoint for a dense toolbar. A regular presentation must retain an explicit usability reserve for native sizing, inter-cluster separation, and the trailing boundary; otherwise select the compact presentation early.

## Regression Safeguard

`DayPlanPlannerStateTests.plannerHeaderCompactsBeforeTheRegularRowConsumesItsBreathingRoom` covers the reserve boundary, and `Tests/macOS/PerformanceRegressionTests.swift` guards the source-level reserve contract. This tightens the compact behavior documented by [Decision 0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md) and the Planner header scenarios.
