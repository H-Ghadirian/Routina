# 0204 — Collapse the control that causes loaded-header overflow

Date: 2026-08-18

## Symptom

The Mac Planner header fit before Home data loaded, then the date-range control extended beyond the trailing edge after the Focus control appeared.

## Root Cause

The date button was icon-only only when the whole header entered its measured compact state. That made the small presentation fallback depend on a broader layout decision that did not reliably change during the loaded-control transition.

## Fix

When the Focus control is visible in Mac Calendar, `Go to date` independently uses its icon-only presentation. Other choice controls retain their separate compact-fit behavior.

## Prevention Rule

When one optional control creates a predictable loaded-state width increase, apply the smallest safe presentation fallback directly from that control's visibility instead of requiring an unrelated aggregate layout transition first.

## Regression Safeguard

`DayPlanPlannerStateTests.plannerHeaderUsesIconOnlyDateButtonWhenFocusControlIsVisible` covers the presentation rule, and `Tests/macOS/PerformanceRegressionTests.swift` guards its wiring into the rendered header. The behavior is recorded in [Decision 0614](../decisions/0614-collapse-planner-date-label-when-focus-is-visible.md) and the Planner header scenarios.
