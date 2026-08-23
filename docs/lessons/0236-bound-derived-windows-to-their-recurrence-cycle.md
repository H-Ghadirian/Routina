# 0236 — Bound derived windows to their recurrence cycle

Date: 2026-08-24

## Symptom

A task that repeated two days after completion could be configured to increase
gradually over seven days before due. Immediately after completion, the new
occurrence was already five days into that nominal window, so its effective
Task Ladder value could start above the value described as its Base.

## Root Cause

The temporal rule validated its lead-day number only against a global maximum.
It did not compare the window with the recurrence cycle that creates the next
due date, and one shared window obscured the lifecycle mismatch across every
configured metric.

## Fix

Each metric now has its own explicit timing policy. Before-due policies on an
After done cadence are capped to that cadence's interval, while a separate
overdue policy starts from the due date and advances one categorical level per
configured interval. Existing shared rules migrate into the new policies and
pass through the same recurrence-aware sanitization.

## Prevention Rule

Any derived time window whose reference point is created by recurrence must be
validated against that recurrence's reachable interval. If behavior can occur
on opposite sides of a boundary, model those meanings as separate modes rather
than overloading one duration.

## Regression Safeguard

`TaskRankingPresentationTests` covers independent per-metric timing, an After
done two-day cap, categorical overdue escalation, and migration from the legacy
shared JSON shape. The task-form layout tests require the shared picker-sentence
editor and prohibit segmented timing controls, toggles, and steppers.

See [Decision 0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md).
