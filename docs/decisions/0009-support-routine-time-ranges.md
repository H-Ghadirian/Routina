# 0009: Support Routine Time Ranges

## Status

Accepted

## Date

2026-05-09

## Context

Exact-time routines are useful when a routine belongs at one moment, but some routines belong to a broader part of the day. Breakfast, for example, should be available in the morning without forcing the user to choose a single exact minute.

At the time this behavior was introduced, recurrence rules used legacy JSON storage. Decision 0010 moves recurrence metadata into SwiftData columns while preserving the time-range behavior described here.

## Decision

Routina stores an optional `RoutineTimeRange` on `RoutineRecurrenceRule`. A range has a start and end time of day and is mutually exclusive with an exact time on the same recurrence rule.

Daily, weekly, and monthly fixed routines can use a time range. The start of the range is the scheduled occurrence time for due-date, notification, calendar, and missed-resolution behavior. The routine can be completed during the range. Once the range ends, the occurrence is treated as a missed timed occurrence that the user can resolve as done, missed, or canceled.

## Consequences

- Existing recurrence rules decode with no time range and keep their previous behavior.
- Time-range routines appear in cadence text as a window, such as "Every day from 7:00 AM to 10:00 AM".
- Notifications for ranged routines fire at the range start unless the user configured a separate reminder.
- The same missed-resolution flow used for exact-time routines is reused for ranges, with the range start stored as the occurrence timestamp.
