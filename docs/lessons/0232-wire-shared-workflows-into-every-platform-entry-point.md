# 0232 — Wire shared workflows into every platform entry point

Date: 2026-08-23

## Symptom

iOS Add Task and Edit Task could link an existing task, and macOS Task Details could do the same, but iOS Task Details only routed Linked Task to creation of a new task.

## Root Cause

The shared relationship picker and the reducer action for directly linking an existing task were already implemented, but the iOS Task Details entry points were still connected only to the create-new route.

## Fix

iOS Task Details now presents the shared Link Task sheet from both `Add a detail` and the visible Linked Tasks card. The sheet can search and confirm an existing task relationship or start creation of a new linked task.

## Prevention Rule

When a shared workflow supports multiple actions, verify each platform entry point exposes the complete workflow instead of checking only that the shared view and reducer actions exist.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` checks that iOS Task Details presents the shared picker, supplies the full relationship catalog, routes confirmed existing-task links, and preserves new-task creation. `TaskDetailPlatformActionParityTests` checks the empty Linked Task entry opens that picker.
