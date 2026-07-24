# 0015 — Persist deliberately revealed task-detail controls

Date: 2026-07-24

## Symptom

After a user added the State control from Task Detail's Add More Details menu, switching to another task and returning caused the State control to disappear.

## Root Cause

The reveal action changed only view-local SwiftUI state. Task changes reset that transient state, and a todo using the implicit default Ready state had no stored value that could make the optional control visible again.

## Fix

Adding State now persists the todo's explicit Ready state when it previously used the implicit default. This preserves the user's disclosure choice without recording a false state transition.

## Prevention Rule

When a user deliberately adds an optional task-detail control that is expected to remain present, store a durable per-task visibility signal or meaningful explicit default; do not rely exclusively on view-local reveal state.

## Regression Safeguard

`TaskDetailTodoStateTests.revealTodoStateInTaskDetailPersistsReadyVisibilityWithoutChangeHistory` verifies that revealing State persists Ready, restores visibility, and does not add a state-change history entry.
