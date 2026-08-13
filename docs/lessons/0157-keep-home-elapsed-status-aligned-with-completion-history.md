# 0157 — Keep Home elapsed status aligned with completion history

Date: 2026-08-13

## Symptom

A Home card reported `2 weeks ago` while its Task Detail and calendar showed a
completion three days earlier.

## Root Cause

Task Detail had been corrected to resolve its elapsed value from completion
history, but Home still used the task's stale `lastDone` summary directly.
Home's relative-time formatter also used the wall clock instead of the Home
presentation snapshot's reference date.

## Fix

Home now resolves its display-only last-completion value from the newest of the
task summary and loaded completion history. Its relative elapsed text uses the
same reference date as the Home snapshot. The persisted `lastDone` value is not
changed and remains the recurrence cursor.

## Prevention Rule

Every completion-history presentation surface must prefer the newest recorded
completion over a stale task summary, and all elapsed text in a snapshot must
use that snapshot's reference date.

## Regression Safeguard

`HomeRoutineDisplayFactoryTests.displayUsesNewerRecordedCompletionForElapsedPresentation`
guards history resolution, and
`HomeTaskListFilteringTests.gentleElapsedStatusUsesTheHomeSnapshotReferenceDate`
guards snapshot-relative elapsed text. The existing
`TaskDetailFeatureCompletionTests.logsLoaded_usesNewerCompletionHistoryForSoftRoutineElapsedTime`
guards Task Detail.
