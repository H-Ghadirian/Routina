# 0181: Allow Gentle Calendar Repeats

- **Status:** Accepted
- **Date:** 2026-06-07
- **Refines:** [0178](0178-make-recurrence-availability-independent.md)

## Context

Routine scheduling now separates two different choices:

- Due style: whether a routine can become overdue (`Due`) or stays low-pressure (`Gentle`).
- Repeat type: whether the cadence is based on elapsed duration (`Interval`) or a calendar pattern (`Calendar`).

Decision [0178](0178-make-recurrence-availability-independent.md) still treated Gentle routines as interval-only. That made the form hide `Repeat type` when Gentle was selected, even though Gentle is about overdue pressure rather than whether the cadence is interval-based or calendar-based.

## Decision

Gentle routines can use the same routine-level repeat types as Due routines: `Interval` or `Calendar`.

- Selecting Gentle must preserve the current repeat type and calendar pattern instead of resetting recurrence to interval.
- Gentle interval routines still use interval frequency to decide when to nudge again.
- Gentle calendar routines use their next calendar occurrence to decide when to show the gentle nudge.
- Checklist-driven Runout routines remain separate because their timing belongs to checklist items rather than one routine-level cadence.

## Consequences

The form is more consistent: Due/Gentle controls pressure, while Interval/Calendar controls cadence. Date math and row badge logic must treat Gentle calendar routines as non-overdue routines whose nudge threshold is their next calendar occurrence.
