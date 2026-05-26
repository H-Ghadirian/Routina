# 0069: Support Optional Task Checklists

## Status

Accepted

## Date

2026-05-26

## Context

Routina already had checklist items, but they were tied to checklist and runout routine formats. Standard routines and one-off todos could keep ordered steps, while checklist items were stripped from save paths and one-off task construction.

Users need a lighter checklist that can attach to any task type during creation and later editing, without turning the task into a checklist-driven routine.

## Decision

Checklist items are now attachable to standard routines, checklist routines, runout routines, and one-off todos.

Checklist and runout routine formats keep their existing meaning: checklist-format routines complete when every item is done, and runout routines derive due state from item timing. For standard routines and todos, checklist items are optional detail/progress items. Ticking them does not complete the task by itself or change the task's schedule. Optional checklist progress is stored in the existing completed checklist item ID storage and is scoped to the current task instance; standard routine progress resets when the routine is completed, while todo checklist state remains with the completed todo.

The task form exposes Checklist as its own section on iOS and macOS so it is available during creation and editing. Task detail shows attached checklist items and exposes a Checklist button in Add More when the task has no checklist yet.

## Consequences

- Code should not assume `RoutineTask.checklistItems` implies a checklist-driven schedule mode.
- Branches that need schedule behavior should continue using `isChecklistDriven` and `isChecklistCompletionRoutine`.
- Add/edit save paths, sharing, import, and direct pull should preserve checklist items for one-off todos.
- Optional checklist item toggles must not create completion logs or advance recurrence.
