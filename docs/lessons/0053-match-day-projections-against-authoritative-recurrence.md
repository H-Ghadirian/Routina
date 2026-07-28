# 0053 — Match Day Projections Against the Authoritative Recurrence

Date: 2026-07-28

## Symptom

A routine scheduled every two weeks on Tuesday starting July 21 appeared in
Home `Today` on the intervening Tuesday, July 28, even though Task Detail
correctly showed August 4 as the next due occurrence.

## Root Cause

Home classified fixed calendar routines from the compatibility recurrence kind
and selected weekday or month day alone. For a structured recurrence, those
fields intentionally provide a simplified projection for older consumers and
do not carry the authoritative every-N interval, fixed start anchor, time zone,
or ending condition.

## Fix

Home fixed-calendar membership now asks `RoutineDateMath` whether the structured
recurrence generator produces an occurrence on the projected day. Compact
weekly and month-day rules keep their existing direct calendar checks.

## Prevention Rule

When a recurrence rule has structured recurrence data, use it as the
authoritative source for occurrence membership. Never infer structured
occurrences from compatibility kind, interval, weekday, or month-day fields.

## Regression Safeguard

`HomeTaskListFilteringTests.filteredPlannedTodayTasksRespectsStructuredWeeklyIntervalAnchor`
verifies that July 21 and August 4 qualify while July 28 does not. The
structured biweekly `Today` scenario in `docs/scenarios/README.md` records the
same product expectation. This follows decisions
[0412](../decisions/0412-add-advanced-recurrence-beside-simple.md) and
[0266](../decisions/0266-show-calendar-routines-in-plan-today.md).
