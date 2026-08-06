# 0085 — Keep one-off completion permanent

Date: 2026-08-06

## Symptom

The new iOS task-choice shortlist could include a completed one-off task when
its completion occurred before the current day.

## Root Cause

The shortlist applied current-period completion semantics to every task. That
rule is appropriate for recurring tasks, but a one-off stays complete forever
regardless of when it was completed.

## Fix

`TaskChoiceCandidateRanking.isCurrentlySelectable` now checks one-off tasks
with `isCompletedOneOff` before applying recurring current-period logic.

## Prevention Rule

Always branch one-off lifecycle semantics before applying recurrence or
current-period completion calculations.

## Regression Safeguard

`TaskChoiceFeatureTests.completedOneOffIsNeverSelectableForTaskChoice` checks
that a one-off completed on an earlier day remains excluded from task choice.
