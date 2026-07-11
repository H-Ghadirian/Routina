# 0371: Drag Day Task Sidebar Rows to Schedule

Date: 2026-07-11

Status: Accepted

Refines: [0095 Drag Tasks to the Planner All Day Lane](0095-drag-tasks-to-planner-all-day-lane.md), [0288 Open Planned Day Task List From Planner Headers](0288-open-planned-day-task-list-from-planner-headers.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)

## Context

The Planner's right-side day task sidebar summarizes planned, assumed-done, and done task work for a selected date. It originally behaved as a mostly read-only review surface, while the left task list supplied the draggable task payloads accepted by the editable Schedule grid and all-day lane.

Users reviewing a selected day's task list should not need to return to the left task list to schedule one of those same tasks.

## Decision

Rows in the right-side Planner day task sidebar can start a task drag using the same task UUID text payload as left-sidebar task rows. Dropping those rows into the editable Schedule grid or all-day lane uses the existing Planner task-drop behavior for the underlying task.

Calendar `List` mode remains read-only. Its per-day agenda columns continue to reuse the day-task row presentation, but they do not provide a drag payload and do not become a scheduling surface.

## Consequences

- The focused right-side day agenda can feed the Schedule view directly without adding a second drop format or a new agenda item model.
- The Schedule view remains the only Calendar task-view mode that accepts drag/drop scheduling interactions.
- Day agenda sections, assumed-done confirmation actions, and task-detail opening behavior remain unchanged.
