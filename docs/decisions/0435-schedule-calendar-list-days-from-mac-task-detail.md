# 0435 — Schedule Calendar List Days From Mac Task Detail

Status: Accepted

Date: 2026-07-26

Refines: [0296 Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md), [0371 Drag Day Task Sidebar Rows to Schedule](0371-drag-day-task-sidebar-rows-to-schedule.md), [0375 Split Time Blocks From Available Windows](0375-split-time-blocks-from-available-windows.md)

## Context

Planner Calendar `List` is useful for reviewing planned work by day, but setting a row’s exact time still required switching to `Schedule` and dragging it into the grid. Selecting the row already opens Task Detail beside the calendar, so that companion pane is the least disruptive place to finish the day’s plan.

The edit must target the day represented by the clicked List column. Changing task-level recurrence, availability, or duration estimates would incorrectly affect other occurrences.

## Decision

On macOS, opening a planned task from a Planner Calendar `List` column carries the clicked day and the row’s specific Planner block, when one exists, into the task-detail companion pane.

Task Detail shows a prominent `Schedule this day` card for that contextual planned row. The card:

- displays the exact clicked date;
- edits the existing day block when the row already has a timed Planner placement;
- creates a timed `DayPlanBlock` for that day when the row is currently any-time or all-day;
- offers a time picker, duration stepper, common duration presets, end-time feedback, and Add/Save/Remove actions;
- rejects overlaps with other Planner blocks and protected Sleep or Away intervals.

These controls mutate only the selected day’s explicit Planner block. They do not rewrite recurrence, task availability, reminder timing, task duration estimates, or other days.

Calendar `List` columns remain read-only: the rows do not gain drag payloads or inline scheduling controls. The mutation surface is the separate task-detail companion pane. Assumed-done and done review rows continue to open normal task details without the planned-row scheduling card.

## Consequences

- A user can review a day in Calendar `List`, select a planned task, and set its time and duration without losing list context.
- Duplicate timed placements remain independently editable because the clicked row carries its block identity.
- Existing Schedule-grid placement and overlap rules remain the persistence contract.
- No task or Planner persistence migration is needed.
