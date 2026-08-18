# 0196 — Persist automatic placement provenance

Date: 2026-08-18

## Symptom

Task Details showed a repeating task at 09:45 while its Planner block still showed 11:15, even after the scheduled-time refresh fix had been applied.

## Root Cause

The first fix inferred automatic ownership only by checking whether a block exactly matched the task's immediately previous generated placement. Once an earlier edit had already been missed, the stale 11:15 block no longer matched the later 10:45 schedule, so a subsequent edit to 09:45 could never recognize or repair it.

## Fix

Timed Planner blocks now persist automatic, manual, or legacy placement provenance. Schedule edits rebase automatic blocks independent of stale coordinates. Untouched legacy generated blocks can be recovered from their unchanged creation/update timestamps or a match with the previous generated placement, then are persisted as automatic. Planner moves, resizes, duplicates, and explicit commits remain manual.

## Prevention Rule

When behavior depends on how persisted state was created, store that provenance. Do not infer ownership forever from mutable coordinates that may already be stale.

## Regression Safeguard

`DayPlanPlannerStateTests.editingScheduledTimeRepairsLegacyAutomaticBlockAfterEarlierMissedEdit` reproduces the 11:15 -> 10:45 missed edit followed by a 09:45 edit. `plannerLoadRepairsStaleAutomaticScheduleEvenWhenNewTimeOverlapsAnotherBlock` reproduces the overlapping 10:00 Daily block from the report. The manual-placement assertion remains in `editingScheduledTimeRebasesAutomaticPlannerBlockButPreservesManualPlacement`, and the behavior is captured in `docs/scenarios/scheduled-time-edit-rebases-automatic-planner-block.md`.
