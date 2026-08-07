# 0099 — Preserve task-list presentation across Stats navigation

Date: 2026-08-07

## Symptom

After opening Mac Stats and returning to Tasks, the task list could unexpectedly apply a saved task-type filter snapshot.

## Root Cause

Stats intentionally preserves selected-task detail state. The Tasks return route then treated that preserved selection as a request to align the task-list type with the selected task, which restored that type's saved filters.

## Fix

Returning from Stats now restores the selected task row and detail without changing the task-list mode or its active filters.

## Prevention Rule

When navigation preserves task context only to restore a detail view, do not infer a task-list mode transition from that retained selection.

## Regression Safeguard

`Tests/macOS/HomeFeatureTaskListModeTests.swift` verifies that a Stats-to-Tasks round trip keeps the selected detail, task-list mode, and filters. The behavior is recorded in `docs/scenarios/README.md`.
