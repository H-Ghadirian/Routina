# 0093: Support All-Day Tasks Across Schedule Types

- Status: Accepted
- Date: 2026-05-28
- Supersedes: [0090](0090-support-manual-all-day-tasks.md)

## Context

Routina added first-class all-day task data for dated one-off todos, but users think of All Day as a task property rather than a todo-only deadline property. Routines can also represent day-long work, events, or responsibilities that belong in the planner's all-day lane without occupying a specific hour.

Keeping all-day support tied to one-off deadlines makes the form inconsistent and prevents recurring tasks from using the all-day lane.

## Decision

Store `RoutineTask.isAllDay` independently from schedule mode and deadline. Task create and edit forms expose the All Day toggle for both routines and todos.

Todos still use their deadline date to decide which day the one-day all-day block appears on. Routines render one-day all-day blocks on their recurrence or due dates. Imported all-day calendar metadata remains the highest-priority source for imported tasks so multi-day calendar spans keep their original start and end dates.

All-day routines should not also create automatic timed planner blocks, even if their recurrence rule carries an explicit time from earlier data.

## Consequences

- Users can mark any task as all day without converting it to a todo.
- The all-day lane can represent recurring all-day routines while preserving the existing calendar-import behavior.
- Manual Routina all-day tasks remain one-day blocks. Multi-day spans still require imported calendar metadata unless a future task-span model is added.
