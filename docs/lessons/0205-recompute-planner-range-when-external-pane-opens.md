# 0205 — Recompute the Planner range when an external pane opens

Date: 2026-08-18

## Symptom

Opening Mac Planner Filters directly left the full Calendar header and Week layout clipped inside the narrowed Planner. If `Go to date` was opened first and Filters was opened afterward, the compact controls and adaptive Day range appeared correctly.

## Root Cause

The adaptive range depended on the calendar child reporting a geometry change. Opening the internal `Go to date` sidebar triggered that callback, but narrowing the Planner with the external filter pane could leave the child at its prior intrinsic width and only clip its parent. The external-pane state changed without an explicit range recalculation.

The header's known Calendar comfort-width rule also waited for an optional child-width probe, allowing regular controls during the same transition.

## Fix

The bounded Planner width is now passed into the calendar content. The adaptive range is recalculated when that parent width or the external-pane state changes, including direct Filter open and close transitions. The header also applies its authoritative Calendar width rule before consulting the optional regular-row measurement.

## Prevention Rule

When an external pane changes the space assigned to a responsive child, recompute adaptive state from the parent's bounded width. Do not rely solely on a descendant geometry callback, because an intrinsically oversized child may be clipped without receiving a new proposal.

## Regression Safeguard

`DayPlanPlannerStateTests.plannerHeaderUsesKnownCalendarWidthBeforeItsRegularWidthIsMeasured` protects the header decision. `Tests/macOS/PerformanceRegressionTests.swift` guards the parent-width wiring and explicit adaptive refresh used when external panes change.
