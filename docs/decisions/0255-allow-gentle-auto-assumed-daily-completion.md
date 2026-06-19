# 0255: Allow Gentle Auto-Assumed Daily Completion

## Status

Accepted

## Date

2026-06-19

## Refines

[0181](0181-allow-gentle-calendar-repeats.md) and [0201](0201-use-ready-to-do-for-gentle-ready-badge.md).

## Context

Auto-assumed daily completion lets a simple daily routine default to done after its daily availability starts, while still allowing the user to confirm the assumed days or mark a day as not done later.

The eligibility rule previously required the routine to use the fixed `Due` schedule mode. That made the option disappear for `Gentle` routines even when the rest of the routine was a simple daily Standard routine.

Decision [0181](0181-allow-gentle-calendar-repeats.md) established that Due/Gentle controls overdue pressure while Interval/Calendar controls cadence. Decision [0201](0201-use-ready-to-do-for-gentle-ready-badge.md) clarified that Gentle routines should stay low-pressure rather than urgent.

## Decision

Auto-assume done is available for simple daily Standard routines in both Due and Gentle styles.

Eligibility still requires:

- A routine, not a todo.
- Standard completion, not checklist or item runout.
- No sequential steps.
- No checklist items.
- A daily recurrence, either daily calendar cadence or a one-day interval cadence.

The setting remains opt-in. Gentle routines keep their non-overdue scheduling semantics; enabling auto-assume only changes the completion assumption for eligible daily occurrences after the availability threshold.

## Consequences

- Mac and iOS create/edit forms can show `Auto-assume done` for eligible Gentle daily routines.
- The existing `autoAssumeDailyDone` data field and sync/backup behavior are unchanged.
- Gentle routines can still be low-pressure, while users who treat them as default-done habits can opt into assumed completion.
- Checklist, runout, multi-step, non-daily, and todo items remain excluded from auto-assumed completion.
