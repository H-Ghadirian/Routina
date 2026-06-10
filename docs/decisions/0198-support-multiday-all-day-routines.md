# 0198 Support Multi-Day All-Day Routines

Status: Accepted

Date: 2026-06-10

Refines: [0093 Support All-Day Tasks Across Schedule Types](0093-support-all-day-routines.md), [0179 Make Routine All Day an Availability Choice](0179-make-all-day-an-availability-choice.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md)

## Context

Routines should remain recurrence-driven. Adding fixed date availability to routines would blur the line between a repeating habit/cadence and a one-off todo with concrete date bounds.

Some all-day routines still naturally last more than one day. Travel is the motivating example: the user chooses the recurrence occurrence that starts the travel routine, then chooses whether that all-day routine spans one day or multiple days.

## Decision

Routine forms keep date availability out of the routine flow. Exact date and date-window availability remain todo-only concepts.

All-day routines get a separate duration choice:

- `One day` means the routine creates a one-day all-day planner span on each recurrence occurrence.
- `Multi-day` stores an integer day count and creates an all-day span from the occurrence start day through that many calendar days.

The stored field defaults to one day, is clamped to a bounded positive value, and is honored only when the task is a non-one-off all-day routine. Timed routines and one-off todos normalize the value back to one day.

## Consequences

A multi-day all-day routine is not fixed to a concrete calendar date. The recurrence rule still decides each start day, and the all-day span length decides how many days that occurrence covers.

The planner must include spans that start before the current visible range but overlap it. Backup, import, CloudKit sharing, and CloudKit repair should preserve the span while treating missing older payload values as one day.

Todos continue to use the separate date/time availability axes from decision 0197. If one-off todos later need a first-class multi-day duration distinct from date-window availability, that should be a separate decision.
