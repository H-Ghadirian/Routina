# 0402: Drag Planner Task Detail Title to Schedule

Date: 2026-07-17

Status: Accepted

Refines: [0095 Drag Tasks to the Planner All Day Lane](0095-drag-tasks-to-planner-all-day-lane.md), [0296 Present Mac Task Details as Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md), [0302 Minimize Fullscreen Mac Task Details to Companion Pane](0302-minimize-fullscreen-mac-task-details-to-companion-pane.md), [0371 Drag Day Task Sidebar Rows to Schedule](0371-drag-day-task-sidebar-rows-to-schedule.md)

## Context

Mac Planner can show task details in a right-side companion pane beside Calendar `Schedule`. The left task list and Planner day-task sidebar already provide task UUID drag payloads that can be dropped into the editable Schedule grid or all-day lane, but the selected task's title in the detail pane was only a label.

When the user is already focused on the selected task's details, returning to the left task list just to schedule that same task adds unnecessary travel.

## Decision

The Mac task detail title starts the same task UUID text drag payload when task details are shown from the Planner-adjacent companion pane. Full Details expanded from that Planner pane keeps the same title drag affordance while it can minimize back to Planner.

The title keeps its existing copy context menu. Other task-detail presentations do not opt into this Planner scheduling drag affordance, and Calendar `List` remains read-only.

## Consequences

- The selected task can be scheduled directly from its details without adding a new drop payload type.
- The editable Calendar `Schedule` grid and all-day lane remain the scheduling destinations.
- List-adjacent, Timeline, and standalone task details keep their non-draggable title behavior unless a future decision expands this affordance.
