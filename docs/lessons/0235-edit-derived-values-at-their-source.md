# 0235 — Edit derived values at their source

Date: 2026-08-23

## Symptom

Task Details placed editable Task Ladder values beside a Changes over time
summary. The controls represented stored Base values, while the summary also
presented due-date-derived Now values, so an edit could appear to change the
current value while actually changing the baseline for future occurrences.

## Root Cause

The presentation reused ordinary direct-edit controls after the metrics gained
a second, time-derived meaning. Nothing in the control boundary distinguished a
stable stored value from a derived read-only projection.

## Fix

Configured Changes over time rules now make all four Task Detail values
read-only, label the time-varying metrics as Base, and direct changes through
full Edit Task. The reducer also rejects stale direct-value actions while a rule
exists.

## Prevention Rule

When a visible value has both stored source and derived current meanings, do
not attach a direct editor to the ambiguous review value. Edit the source and
its derivation rule together, and enforce the restriction below the view layer.

## Regression Safeguard

The Task Detail time-varying-values scenario covers the intended journey.
Shared source checks cover both platform presentations, and
`TaskDetailTodoStateTests` verifies that direct value actions cannot mutate a
task while its rule is configured.

See [Decision 0648](../decisions/0648-keep-time-varying-task-ladder-values-read-only-in-details.md)
and [the regression scenario](../scenarios/task-detail-locks-time-varying-ladder-values.md).
