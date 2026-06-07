# 0182: Show Todo All Day as Availability

## Status

Accepted

## Date

2026-06-07

Refines [0179](0179-make-all-day-an-availability-choice.md) for one-off todo form controls.

## Context

[0179](0179-make-all-day-an-availability-choice.md) kept todo all-day separate from `Set deadline`, because all-day is a task property and does not require a deadline. After routine scheduling moved all-day under `Availability`, todos still showed a standalone `All-day block` toggle near the task kind picker. That made the form use two concepts for the same persisted `RoutineTask.isAllDay` field.

Todos do not currently have a first-class scheduled availability time or time window separate from deadline. Routine exact-time and window availability are stored on recurrence rules, so exposing those choices for todos would imply a capability the model does not persist.

## Decision

Todo create/edit forms present `Availability` directly below the Routine/Todo picker.

For todos, `Availability` includes only `Any time` and `All-day`. Selecting `All-day` toggles `RoutineTask.isAllDay` but does not create, enable, or move a deadline. `Set deadline` remains its own optional date control.

Todo forms do not show a schedule summary or row badge preview card. Deadline and reminder controls are enough for one-off task scheduling.

Routine forms keep the fuller Availability set: `Any time`, `All-day`, `At time`, and `Window`.

## Consequences

- Todo and routine forms use the same vocabulary for all-day intent.
- Users can mark a todo all-day without accidentally adding a deadline.
- The UI no longer advertises todo exact-time/window availability until there is a first-class data model for it.
- The right-side preview area remains reserved for routine row badge behavior, where it has real explanatory value.
