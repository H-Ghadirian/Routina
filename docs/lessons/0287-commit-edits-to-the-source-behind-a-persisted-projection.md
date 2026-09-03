# 0287 — Commit edits to the source behind a persisted projection

Date: 2026-09-03

## Symptom

Resizing a completed task-Focus rectangle in Mac Calendar changed its visible
height but not the Focus total in Task Details. Switching to Backlog and returning
to Planner restored the rectangle's old size.

## Root Cause

The resize path treated every persisted `DayPlanBlock` as independent Planner
data. Completed Focus rectangles are different: they are persisted Calendar
evidence derived from an authoritative `FocusSession`. The gesture saved only the
evidence, so other surfaces kept reading the old session, and later Focus
reconciliation correctly—but unexpectedly—projected that stale source again.

## Fix

Planner now identifies the owning completed Focus session when resize begins. On
gesture completion it updates that session, rebuilds all of its Calendar evidence,
saves the combined change, and refreshes dependent surfaces. Planner Undo/Redo
captures both the session fields and all affected day-block snapshots. The Task
Details Focus editor uses the same shared source-and-evidence update operation.

## Prevention Rule

Before allowing an edit on persisted presentation data, determine whether the
record is authoritative or a projection. If it is a projection, mutate its source
and regenerate every persisted projection in the same committing operation; include both
in undo, refresh, and regression coverage.

## Regression Safeguard

`DayPlanPlannerStateTests.resizingCompletedTaskFocusUpdatesItsSourceAndSurvivesPlannerRecreation`
verifies the session duration, Task Detail summary input, stored Calendar block,
reconciliation behavior, and combined Undo/Redo path.

Related decision: [0715 — Update recorded Focus at its source when resizing Planner evidence](../decisions/0715-update-recorded-focus-at-its-source-when-resizing-planner-evidence.md).
