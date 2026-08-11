# 0147 — Keep Flag assignment aligned with auto-assume eligibility

Date: 2026-08-12

## Symptom

A Standard routine scheduled every two weeks on Tuesday could not receive an
`Auto Assumed Done` Flag, even though it had one scheduled occurrence per day.

## Root Cause

`RoutineAssumedCompletion.canEnable` added a second check that accepted only
Gentle routines, Tracking entries, and rolling `After done` routines. The
shared eligibility rule already accepted fixed calendar schedules, so Flag
assignment disagreed with actual assumed-completion eligibility and the
documented product behavior.

## Fix

Flag enablement now accepts every schedule shape accepted by the shared
eligibility rule. A fixed every-two-weeks Tuesday routine can therefore receive
and activate an Auto Assumed Done Flag.

## Prevention Rule

Do not add a narrower behavior-specific gate after evaluating a shared
eligibility contract. Assignment, persistence, synthetic completion, and
notification behavior must all use the same eligibility boundary.

## Regression Safeguard

`TaskDetailFlagSuggestionTests.autoAssumeFlagCanBeSelectedForFixedEveryTwoWeeksTuesdaySchedule`
exercises Flag selection for the affected schedule. The corresponding scenario
is recorded in `docs/scenarios/README.md`.
