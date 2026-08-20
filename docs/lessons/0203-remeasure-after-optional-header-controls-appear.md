# 0203 — Remeasure after optional header controls appear

Date: 2026-08-18

## Symptom

The Mac Planner header fit during Home loading, then stretched past the right edge after Home data loaded and the Planner Focus button appeared.

## Root Cause

The compact fallback did not distinguish the loaded header's extra Focus control from the loading header. It also trusted a parent-provided width even when the header's own visible measurement was tighter.

## Fix

Home now passes whether the Planner Focus control is actually visible. When it is visible, the Calendar header requires a wider comfort threshold before using full segmented controls. The header also uses the tighter of the parent-supplied width and its own measured width for compact decisions.

## Prevention Rule

Responsive toolbar decisions must be recalculated from the controls that are currently visible, not from the loading shell or an optimistic ancestor width.

## Regression Safeguard

`DayPlanPlannerStateTests.plannerHeaderUsesCompactControlsEarlierWhenFocusControlIsVisible` covers the loaded Focus-control threshold, and `DayPlanPlannerStateTests.plannerHeaderUsesTheTighterVisibleWidthWhenParentWidthIsOptimistic` covers width selection. `Tests/macOS/PerformanceRegressionTests.swift` guards the source-level wiring from Home into the Planner header.

[0205](0205-recompute-planner-range-when-external-pane-opens.md) further requires external pane transitions to reapply the bounded parent width instead of waiting for child geometry.
