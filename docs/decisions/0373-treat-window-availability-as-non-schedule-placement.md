# 0373: Treat Window Availability as Non-Schedule Placement

Date: 2026-07-11

Status: Accepted

Refines: [0009 Support Routine Time Ranges](0009-support-routine-time-ranges.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md), [0183 Support Todo Availability Time Windows](0183-support-todo-availability-time-windows.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0372 Hide Completed Tasks From Calendar Schedule](0372-hide-completed-tasks-from-calendar-schedule.md)

Refined by: [0375 Split Time Blocks From Available Windows](0375-split-time-blocks-from-available-windows.md), [0387 Keep Completed Scheduled Blocks Visible](0387-keep-completed-scheduled-blocks-visible.md)

## Context

Routina supports `Window` timing so routines and todos can be available during a span such as 21:00-03:00 without forcing the user to choose one exact moment. Earlier Planner behavior treated the start of that window as an automatic timed Calendar `Schedule` placement. That made availability windows look like user-scheduled blocks and caused auto-assumed routine days to keep appearing in the timed grid.

Users expect `Window` to mean "this is when the task is available", not "place this task on the editable timed calendar by default." A task should appear in the timed `Schedule` automatically only when it has an exact time, exact date-time, or was explicitly placed through Planner drag/drop or slot creation.

## Decision

Calendar `Schedule` treats `Window` timing as availability metadata, not automatic placement metadata. Routine and todo time windows continue to drive availability, notification, and missed-resolution behavior, but Planner does not create default timed blocks from window starts.

Planner may remove stale automatically generated window blocks when they still exactly match the old window-start placement. Manually moved or resized Planner blocks for the same task remain because those represent explicit user placement.

Task-backed Schedule blocks, including exact-time blocks, explicit timed placements, and all-day task placements, are hidden for a day once that task day is recorded canceled, missed, or is synthetically assumed done. Decision 0387 later keeps qualifying scheduled blocks visible after completion or fulfillment. Day agenda, Calendar `List`, and the right-side day task sidebar remain the review surfaces for `Assumed done` and `Dones`.

## Consequences

- `At time` remains the task-form choice for automatic timed Calendar placement.
- `Window` remains available for broad availability and overnight routine logic without crowding the editable Schedule grid.
- Old matching auto-window blocks are cleaned up during Planner exact-schedule refresh, while explicit user placements survive.
- Calendar `Schedule` stays focused on unresolved intentional plans; Calendar `List` and day task sidebars continue to show completion review.
