# 0179: Make Routine All Day an Availability Choice

## Status

Accepted

## Date

2026-06-07

Refines [0093](0093-support-all-day-routines.md) and [0178](0178-make-recurrence-availability-independent.md) for task form scheduling controls.

## Context

[0093](0093-support-all-day-routines.md) made all-day a first-class task property for todos and routines. [0178](0178-make-recurrence-availability-independent.md) then made routine availability independent from repeat type.

The form still exposed routine all-day as a separate top-level checkbox while Availability exposed exact time and window choices. That allowed the UI to imply conflicting states such as an all-day routine that is also due at an exact time or within a time window.

For one-off todos, all-day remains a task-level property. It can matter even without a deadline, so it should not be nested under the deadline controls.

## Decision

Routine forms present all-day as part of the timing choice for the schedule being edited.

For routines, Availability includes `Any time`, `All day`, `At time`, and `Window`. It appears before repeat type and calendar pattern controls because it answers when a due-day occurrence is actionable before the user chooses how that due day is calculated. Selecting `All day` clears exact-time and time-window recurrence flags, and save/edit builders ignore stale recurrence timing whenever the task is marked all day.

For one-off todos, the all-day control stays independent from `Set deadline`. The deadline section only decides whether there is a deadline and, when present, which date or date/time it uses. The task kind picker remains a compact Routine/Todo control without a visible `Create as` heading.

## Consequences

- Users cannot intentionally create an all-day routine that also has an exact-time or window availability.
- Todo all-day intent remains available even when the todo has no deadline.
- Existing data with stale recurrence timing remains safe because all-day saves resolve to untimed recurrence rules.
- All-day still remains persisted as `RoutineTask.isAllDay`; this record only changes how routine forms present and normalize that property.
