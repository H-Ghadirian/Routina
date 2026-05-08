# 0002: Treat Exact-Time Routines as Missed After Their Scheduled Day

## Status

Accepted

## Date

2026-05-08

## Context

Routines with an explicit calendar time, such as "every Thursday at 18:30", represent an occurrence that only belongs to that scheduled day. The previous behavior kept the outstanding occurrence overdue on following days and highlighted the overdue range through today. That made exact-time routines look like rolling deadline tasks, even though the user missed the occurrence window.

## Decision

When an exact-time routine is not completed on its scheduled calendar day, Routina treats that occurrence as missed once the next day starts. The missed occurrence should remain visible on its scheduled day in the calendar, but later days should not be painted as part of an overdue range.

The default Done action on a later day must not silently backfill the missed occurrence. Users may still select the scheduled occurrence day in the calendar to correct history intentionally.

Missed exact-time occurrences consume their scheduled slot for forward-looking scheduling, similar to completed occurrences, but they do not create completion logs, increase completion counts, or use Done styling.

## Consequences

- Exact-time routines use "Missed" presentation instead of "Overdue by N days" after the scheduled day passes.
- Calendar highlighting marks the missed scheduled day only; today keeps its normal today treatment, and the next scheduled occurrence remains visible as the due date.
- Home grouping and badges can distinguish missed exact-time routines from ordinary overdue interval/checklist routines.
- Notifications must not be scheduled for the missed occurrence; future notifications target the next scheduled occurrence.
- Missed styling must not use red, because red is reserved for true overdue states.
- Rolling interval and checklist-driven routines keep their existing overdue behavior.
