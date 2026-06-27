# 0287: Remove Deleted Task Blocks From Planner

## Status

Accepted

## Date

2026-06-27

## Refines

- [0105: Remove Abandoned Focus Blocks from Planner](0105-remove-abandoned-focus-blocks-from-planner.md)
- [0269: Support Planner Slot Actions](0269-support-planner-slot-actions.md)
- [0286: Present Planner Slot Actions in a Sidebar](0286-present-planner-slot-actions-in-sidebar.md)

## Context

Task-backed planner blocks are stored as `DayPlanBlockRecord` rows with a `taskID`. They can be created manually, from Planner slot actions, or from task-backed focus flows. If the user deletes the task later, leaving those persisted planner blocks behind makes the Planner show work that no longer has an owning task.

Routina still keeps several other planner-visible models separate: automatic timeline suggestions are derived from history, focus sessions are focus history, Away and Sleep are protected session history, and events are standalone calendar-visible records.

## Decision

Deleting a task removes all persisted `DayPlanBlockRecord` rows whose `taskID` matches the deleted task. This cleanup applies to first-party Home deletion, Task Detail deletion, CloudKit direct-pull deletion housekeeping, and orphaned task-row cleanup.

The Planner reloads persisted blocks when its visible task set changes and clears the selected planner block if a reload no longer contains it, so deleting a task from an edit surface removes its matching calendar block from an open Planner as well as from storage.

The cleanup does not delete automatic timeline suggestions, completed focus history, Away sessions, Sleep sessions, standalone events, or unrelated planner blocks.

## Consequences

- Deleted tasks no longer leave orphaned task-backed planner blocks.
- Planner selection state cannot keep editing a block that was removed by task deletion.
- Historical activity models remain independently preserved unless their own deletion rules say otherwise.
