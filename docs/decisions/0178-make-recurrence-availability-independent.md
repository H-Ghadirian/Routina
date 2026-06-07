# 0178: Make Recurrence Availability Independent

## Status

Accepted

## Date

2026-06-07

Refines [0009](0009-support-routine-time-ranges.md) and [0177](0177-separate-interval-and-calendar-repeat-controls.md) for routine recurrence forms.

## Context

[0177](0177-separate-interval-and-calendar-repeat-controls.md) split repeat controls into `Interval` and `Calendar` so users first choose whether a routine repeats after an elapsed duration or on a calendar pattern.

Availability was still nested inside specific recurrence branches. Daily showed only exact time or window, weekly and monthly showed optional availability, and interval discarded timing entirely. That made the form imply that availability belonged to the selected repeat pattern instead of being a separate scheduling dimension.

## Decision

Routine forms present Availability as its own section for Due routines and Gentle routines whose cadence is still routine-level. For Due routines, this applies regardless of whether the repeat type is `Interval` or `Calendar` and regardless of whether the calendar pattern is Daily, Weekday, or Month day. Gentle routines remain interval-based, but they can still choose when the nudge-day work is actionable.

Availability includes these choices:

- `Any time`: the routine is available for the whole scheduled day.
- `All-day`: the routine appears in the planner all-day lane on the scheduled day.
- `At time`: the routine becomes available at the selected time on the scheduled day.
- `Window`: the routine is available only between the selected start and end times.

Interval recurrence rules may store an exact time or time range. The interval still determines the due day from the rolling duration anchor; availability determines when that due day is actionable.

Checklist-driven Runout schedule modes continue to omit recurrence availability because their timing belongs to each checklist item rather than to one routine-level occurrence.

## Consequences

- Users no longer see two different places to configure timing for repeat routines.
- Daily calendar routines can be any-time routines, matching weekday and month-day behavior.
- Interval routines with exact time or windows, including Gentle interval routines, must preserve those values in SwiftData columns, sync decoding, save/edit flows, and date math.
- Timed interval routines use missed-occurrence handling when their exact time or window passes unresolved.
