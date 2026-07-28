# 0055 — Resolve Today Before Advancing Recurrence

Date: 2026-07-28

## Symptom

After a current-day time window ended, Task Detail showed a disabled `Missed` primary button for today even though selecting the same routine's prior occurrence produced an enabled Done action.

## Root Cause

The current-day completion-target branch asked the recurrence engine for the task's due date after the window had ended. At that point the due date had advanced to a later recurrence, so the branch discarded it as not occurring today. Past selected days used the scheduled occurrence directly and did not have this failure.

## Fix

Current-day exact-time completion targeting now chooses the latest scheduled occurrence that is not later than the reference time. Single-occurrence presentation is also available to the calendar's Missed and Canceled controls while the multi-occurrence selector keeps its existing behavior.

## Prevention Rule

When resolving an explicit calendar-day action, derive the occurrence identity from that selected day's authoritative schedule before consulting next-due recurrence state.

## Regression Safeguard

`RoutineDateMathTests.completionTargetDate_keepsEndedCurrentDayWindowActionable` protects the current-day target, and `TaskDetailFeatureCompletionTests.singleEndedOccurrenceExposesCalendarMissedAndCanceledActions` protects the selected-day outcome presentation.
