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

Routine forms present Availability as its own section for standard scheduled routines, regardless of whether the repeat type is `Interval` or `Calendar` and regardless of whether the calendar pattern is Daily, Weekday, or Month day.

Availability has three choices:

- `Any time`: the routine is available for the whole due day.
- `At time`: the routine becomes available at the selected time on the due day.
- `Window`: the routine is available only between the selected start and end times.

Interval recurrence rules may store an exact time or time range. The interval still determines the due day from the rolling duration anchor; availability determines when that due day is actionable.

Soft interval and checklist-driven schedule modes continue to omit recurrence availability because their visibility is not driven by a single routine occurrence time.

## Consequences

- Users no longer see two different places to configure timing for repeat routines.
- Daily calendar routines can be any-time routines, matching weekday and month-day behavior.
- Interval routines with exact time or windows must preserve those values in SwiftData columns, sync decoding, save/edit flows, and date math.
- Timed interval routines use missed-occurrence handling when their exact time or window passes unresolved.
