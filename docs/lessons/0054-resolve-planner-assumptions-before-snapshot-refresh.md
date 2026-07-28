# 0054 — Resolve Planner assumptions before snapshot refresh

Date: 2026-07-28

## Symptom

Clicking the green check on a Mac Planner Calendar List `Assumed done` row persisted the completion, but the row could remain in `Assumed done` for many seconds before moving to `Dones`.

## Root Cause

The row presentation depended entirely on the Planner's authoritative data snapshot. Planner intentionally defers that full snapshot refresh while a task-detail companion pane is open or Mac scrolling is active, so the successful mutation had no lightweight presentation state capable of resolving the cached synthetic row.

## Fix

After persistence succeeds, Planner records a day-and-task-scoped local resolution. A confirmed row is immediately projected into `Dones`, while a missed row is immediately removed. The overlay resets when a new authoritative snapshot arrives. Direct widget-stat refresh calls were also removed from these actions because the shared routine-update notification already owns coalesced widget refresh scheduling.

## Prevention Rule

User-initiated mutations on cached Planner rows must update the affected visible presentation immediately. Do not force an unbounded snapshot fetch, history regroup, or widget-stat computation into the interaction path; use a bounded local projection and let the established snapshot invalidation reconcile it later.

## Regression Safeguard

`DayPlanDayTaskListPresentationTests` verifies confirmed and missed overlays, including day scoping and exact duration preservation. `PerformanceRegressionTests` verifies that the overlay performs no SwiftData fetch or model-context work. The Mac Planner scenario in `docs/scenarios/README.md` records the immediate Calendar List behavior.
