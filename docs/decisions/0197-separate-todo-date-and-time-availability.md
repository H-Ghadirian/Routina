# 0197 Separate Todo Date and Time Availability

Status: Accepted

Date: 2026-06-10

Refines: [0196 Support Todo Availability Date Bounds](0196-support-todo-availability-date-bounds.md), [0183 Support Todo Availability Time and Windows](0183-support-todo-availability-time-windows.md)

Refined by: [0198 Separate Task Date and Time Availability](0198-separate-task-date-and-time-availability.md)

## Context

Decision 0196 anchored todo availability by storing optional start and end dates, but the first implementation treated those bounds as full date-time values. That made exact availability work, but it blended two different user decisions: which date or date range a todo is available on, and which time of day it is available during.

Users need to combine those independently. For example, a todo may be available on one exact date at any time, during a date window at a repeated time window each day, or on any date at a preferred time.

## Decision

Todo forms present availability as two independent axes:

- Date availability: `Any date`, `At date`, and `Date window`.
- Time availability: `Any time`, `All-day`, `At time`, and `Window`.

One-off todos continue to store date availability in `availabilityStartDate` and `availabilityEndDate`, but those values are day bounds rather than combined date-time endpoints. Time availability remains stored through `isAllDay` and the one-off recurrence rule's `timeOfDay` or `timeRange`.

## Consequences

`At date + At time` represents an exact date and time. `Date window + Window` represents the same time window on each eligible date in the date window. `Any date + At time` can store a preferred time without anchoring the todo to a planner day.

Planner placement should combine the selected date with recurrence time metadata. It should not infer a time from date availability bounds. Deadline and reminder remain separate commitment and notification concepts.
