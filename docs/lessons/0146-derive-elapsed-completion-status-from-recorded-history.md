# 0146 — Derive elapsed completion status from recorded history

Date: 2026-08-12

## Symptom

Task Detail could show an old `days since last time` value while Calendar
showed a newer recorded completion for the same task.

## Root Cause

The status calculation read only the task's cached `lastDone` value, while
Calendar correctly renders completion-log history. Those sources can briefly
or permanently differ after independent history updates or sync reconciliation.

## Fix

Task Detail now derives elapsed completion status from the newest recorded
completion across `lastDone` and completion logs. It keeps `lastDone` unchanged
as the recurrence cursor.

## Prevention Rule

When presenting completion history, use the latest recorded completion and
treat `lastDone` as a legacy fallback or recurrence field, not the sole history
source.

## Regression Safeguard

`TaskDetailFeatureCompletionTests.logsLoaded_usesNewerCompletionHistoryForSoftRoutineElapsedTime`
asserts that a newer completion log produces the matching elapsed-status text.
