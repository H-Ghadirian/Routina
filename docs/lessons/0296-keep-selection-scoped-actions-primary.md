# 0296 — Keep selection-scoped actions primary

Date: 2026-09-04

## Symptom

Selecting Today in a task's calendar changed the prominent action to
`Confirm 49 assumed days`, even though the visible selection named one date.

## Root Cause

Task Detail presentation had a special condition that promoted bulk confirmation
whenever Today was assumed done and any older assumed dates existed. The condition
used selection as permission to broaden the mutation instead of treating selection
as the scope of the primary action.

## Fix

The prominent completion action now always targets the selected assumed date.
Eligible counted bulk confirmation remains available as a secondary action, and
full Mac Task Details places it in the adjacent `⋮` menu after `Missed`.

## Prevention Rule

When a surface exposes an explicit date or occurrence selection, its primary action
must operate on that selection. An action that mutates multiple records must never
replace the selection-scoped primary action; give it explicit scope, an affected
count, and secondary placement.

## Regression Safeguard

`TaskDetailFeatureCompletionTests.completionButtonForTodayStaysScopedToTodayWhenBulkConfirmationIsAvailable`
verifies the primary title and action while older assumed dates exist.
`TaskDetailPlatformActionParityTests.macFullDetailGroupsSecondaryTaskActionsInAnOverflowMenu`
protects the counted bulk action's secondary Mac menu placement.

Related decision: [0726 — Keep Selected Assumed-Day Confirmation Primary](../decisions/0726-keep-selected-assumed-day-confirmation-primary.md).
