# 0198 Separate Task Date and Time Availability

Status: Accepted

Date: 2026-06-10

Refines: [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md)

## Context

Decision 0197 split todo availability into separate date and time axes, but routines still only exposed time availability. That made todos and routines inconsistent: a routine could say it is available at a time or time window, but not that the routine is active only on one date or inside a date window.

Routine repeat controls still answer which cadence or calendar pattern produces eligible days. Date availability should not replace that cadence; it should constrain the dates where the cadence can produce occurrences.

## Decision

All task forms present availability as two independent axes:

- Date availability: `Any date`, `At date`, and `Date window`.
- Time availability: `Any time`, `All-day`, `At time`, and `Window`.

Tasks store date availability in `availabilityStartDate` and `availabilityEndDate` as day bounds, regardless of whether the task is a todo or routine. Todo time availability remains stored through `isAllDay` and the one-off recurrence rule. Routine time availability remains stored on the routine recurrence rule.

For routines, date availability filters the routine recurrence. A weekly routine with a date window still occurs only on its configured weekday, and only if that weekday falls inside the availability window.

## Consequences

Creation, editing, drafts, backup/import, CloudKit sharing, and direct CloudKit repair preserve date availability for routines.

Planner timed blocks, all-day blocks, due-date math, missed exact-time handling, and auto-assumed daily completions must respect routine date availability bounds. Routines outside their date availability should not become due or auto-complete from recurrence alone.
