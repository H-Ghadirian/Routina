# 0179: Make All Day an Availability Choice

## Status

Accepted

## Date

2026-06-07

Refines [0093](0093-support-all-day-routines.md) and [0178](0178-make-recurrence-availability-independent.md) for task form scheduling controls.

## Context

[0093](0093-support-all-day-routines.md) made all-day a first-class task property for todos and routines. [0178](0178-make-recurrence-availability-independent.md) then made routine availability independent from repeat type.

The form still exposed all-day as a separate top-level checkbox while Availability exposed exact time and window choices. That allowed the UI to imply conflicting states such as an all-day routine that is also due at an exact time or within a time window.

## Decision

Task forms present all-day as part of the timing choice for the schedule being edited.

For routines, Availability includes `Any time`, `All day`, `At time`, and `Window`. Selecting `All day` clears exact-time and time-window recurrence flags, and save/edit builders ignore stale recurrence timing whenever the task is marked all day.

For one-off todos, the deadline timing choice lives with the deadline controls as `At time` or `All day`. The task kind picker remains a compact Routine/Todo control without a visible `Create as` heading.

## Consequences

- Users cannot intentionally create an all-day routine that also has an exact-time or window availability.
- Existing data with stale recurrence timing remains safe because all-day saves resolve to untimed recurrence rules.
- All-day still remains persisted as `RoutineTask.isAllDay`; this record only changes how the form presents and normalizes that property.
