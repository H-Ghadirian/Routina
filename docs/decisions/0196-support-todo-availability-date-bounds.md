# 0196 Support Todo Availability Date Bounds

Status: Accepted

Date: 2026-06-09

Refines: [0183 Support Todo Availability Time and Windows](0183-support-todo-availability-time-windows.md)

Refined by: [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md)

## Context

Decision 0183 gave todos the same availability timing choices as routines: any time, all-day, at time, and window. That covered the time-of-day metadata, but one-off todos also need a concrete date anchor. Without a date bound, a todo can store "at 9:00" or "9:00 to 10:00" without saying which day that availability belongs to.

Deadline and reminder remain separate concepts. A todo can be available on a date or during a date/time window without also becoming a deadline or notification.

## Decision

One-off todos store optional `availabilityStartDate` and `availabilityEndDate` date bounds.

The task form treats todo availability as date-aware:

- `Any time` clears availability date bounds.
- `All-day` stores a single all-day availability date.
- `At time` stores an exact availability date/time.
- `Window` stores start and end date/times.

Routine availability remains recurrence-relative and continues to store only time-of-day or time-window metadata on the recurrence rule.

## Consequences

Planner exact-task placement can create blocks for one-off todos from availability date bounds without requiring a deadline. Date/time windows use their start/end duration on the planner day.

Backups, creation drafts, CloudKit sharing payloads, and direct CloudKit repair paths preserve the date bounds.
