# 0401 Duplicate Planner Blocks With Command Drag

Status: Accepted

Date: 2026-07-17

Refines: [0095 Drag Tasks to the Planner All Day Lane](0095-drag-tasks-to-planner-all-day-lane.md), [0265 Scope Planner Block Undo to Planner](0265-scope-planner-block-undo-to-planner.md), [0371 Drag Day Task Sidebar Rows to Schedule](0371-drag-day-task-sidebar-rows-to-schedule.md), [0375 Split Time Blocks From Available Windows](0375-split-time-blocks-from-available-windows.md)

## Context

Planner Schedule blocks can already be moved by dragging, and explicit Planner placements are user-owned records. When a user wants the same task placed in multiple timed slots, moving the original block forces them to recreate the source placement manually.

On macOS, Command-drag is the expected desktop gesture for copying during drag and drop.

## Decision

On macOS Planner Calendar `Schedule`, holding Command while dragging a persisted timed Planner block creates a duplicate timed Planner block at the drop target. The duplicate keeps the original block's task, title snapshot, emoji snapshot, and duration, receives a fresh planner block ID, and leaves the original block in place.

The duplicate drop uses the same timed Schedule constraints as a move: protected-time conflicts are rejected, timed Planner blocks do not overlap other timed Planner blocks, and the edit participates in Planner undo/redo. Normal block dragging without Command continues to move the existing block.

The all-day lane keeps its existing model from [0095](0095-drag-tasks-to-planner-all-day-lane.md): dropping a timed block there converts the task to all-day and removes the timed placement instead of creating a separate all-day block duplicate. Calendar `List` remains read-only.

## Consequences

Users can quickly place repeated timed work without disturbing the original slot.

Planner block IDs remain unique, so deleting, moving, resizing, and undoing the copied block affects only that placement.

All-day task visibility continues to be derived from task data rather than a parallel all-day block model.
