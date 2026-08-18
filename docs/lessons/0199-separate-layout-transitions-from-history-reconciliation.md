# 0199 — Separate layout transitions from history reconciliation

Date: 2026-08-18

## Symptom

Closing the macOS task-detail companion pane was visibly slow and laggy, especially with a substantial Focus and task history.

## Root Cause

The pane close widened Planner and changed its adaptive visible range. That layout-only change synchronously reconciled every count-up Focus session, and the reconciliation loaded and saved Planner blocks once per segment even when storage was already identical. Closing also released a deferred full Home refresh inside the same animated transaction, multiplying SwiftUI layout, reducer, query, and persistence work on the main actor.

## Fix

Adaptive range changes no longer reconcile Focus history. Reconciliation batches generated segments by day and skips unchanged days, while a deferred Home refresh waits for a short post-transition quiet window before running.

## Prevention Rule

Never attach whole-history repair or unconditional persistence to an adaptive layout or presentation-state change. Reconciliation must run only at semantic invalidation boundaries, compare against stored state, and batch the smallest durable write set.

## Regression Safeguard

`DayPlanPlannerStateTests.reconcilesPackedCountUpTagFocusSegmentsFromPauseResumeActionLogs` verifies one batched day write followed by a no-op reconciliation. `PerformanceRegressionTests` verifies that adaptive range changes do not call Focus reconciliation and that deferred Home refresh waits through the task-detail transition. The matching behavior is recorded in `docs/scenarios/README.md` and Decision 0608.
