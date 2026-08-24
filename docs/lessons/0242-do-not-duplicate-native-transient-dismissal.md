# 0242 — Do not duplicate native transient dismissal

Date: 2026-08-24

## Symptom

The Mac Actual-time and Focus action popovers showed a Cancel button even though
clicking outside the transient popover already dismissed it without applying
anything. The extra action consumed footer space and competed visually with the
single action the person opened the popover to perform.

## Root Cause

The popover footer copied a sheet-style secondary action without accounting for
the native transient dismissal behavior of an anchored macOS popover.

## Fix

Both action popovers now show only their committing action. Clicking outside
continues to dismiss the popover without logging Actual time or starting Focus.

## Prevention Rule

Do not add an explicit Cancel button to a transient popover when native outside-
click dismissal is already safe, discoverable, and noncommitting. Keep Cancel
when dismissal would otherwise apply destructive or immediate edits, or when the
surface is modal and has no equivalent native escape path.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` verifies that neither Mac Effort action editor
contains a Cancel button or a redundant cancel keyboard shortcut while retaining
its explicit primary action.

See [Regression Scenarios](../scenarios/README.md#mac-task-detail-effort-stays-compact-and-reports-focus-history).
