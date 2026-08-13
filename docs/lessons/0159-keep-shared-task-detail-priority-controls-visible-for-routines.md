# 0159 — Keep shared task-detail priority controls visible for routines

Date: 2026-08-13

## Symptom

The macOS Task Detail Priority section was visible for todos but missing from routine details.

## Root Cause

The Priority-section refactor added the shared control to the todo header and removed the previous per-control layout, but it did not add the new shared section to the routine header.

## Fix

Both todo and routine headers now render the same expandable Priority section. The layout regression test verifies both task types share that section and its four controls.

## Prevention Rule

When replacing a shared detail control, verify every task-type header that rendered its predecessor now renders the replacement.

## Regression Safeguard

`TaskDetailMacHeaderControlLayoutTests.priorityControlsShareOneExpandableSectionForEveryTaskType` inspects both header builders and the shared Priority-controls grid.
