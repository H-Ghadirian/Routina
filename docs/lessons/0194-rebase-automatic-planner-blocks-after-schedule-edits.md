# 0194 — Rebase automatic Planner blocks after schedule edits

Date: 2026-08-18

## Symptom

After changing a task's scheduled time, the task detail summary showed the new time but the open Planner block stayed at the old time until a later refresh, and could remain stale while the task-detail companion pane was open.

## Root Cause

Routine updates were deferred whenever the external task inspector was presented. Separately, Planner's existing automatic-block reconciliation only refreshed a block when its start minute was already unchanged, so it could not recognize that a persisted block at the previous automatic time should move to the new time.

## Fix

Routine saves now compare the previous and updated task schedules and rebase persisted blocks only when their start and duration still exactly match the previous automatic placement. The routine-update notification refreshes the Planner snapshot while the inspector remains open. Manual moved or resized placements are left unchanged.

## Prevention Rule

Schedule edits must reconcile persisted automatic placements using the previous schedule as well as the updated schedule. Do not infer that a task's existing block is automatic when its placement no longer exactly matches the prior automatic result, and do not defer correctness refreshes solely because the detail inspector is visible.

## Regression Safeguard

`DayPlanPlannerStateTests.editingScheduledTimeRebasesAutomaticPlannerBlockButPreservesManualPlacement` covers automatic rebasing and manual-placement preservation. `routineUpdateRefreshesPlannerSnapshotWhileTaskInspectorIsOpen` guards the immediate notification-refresh path. The behavior is also captured in `docs/scenarios/scheduled-time-edit-rebases-automatic-planner-block.md`.
