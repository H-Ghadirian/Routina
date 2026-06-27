# 0288: Open Planned Day Task List From Planner Headers

## Status

Accepted

## Date

2026-06-27

## Refines

- [0286: Present Planner Slot Actions in a Sidebar](0286-present-planner-slot-actions-in-sidebar.md)
- [0191: Support One-Day Planner View](0191-support-one-day-planner-view.md)

## Context

Planner week and day modes make planned blocks visible in the calendar grid, but users sometimes need a compact checklist-style view of what was planned for a single date without visually scanning the whole timeline.

The Planner already has a stable right-side sidebar for secondary planner content after empty-slot creation moved out of transient popovers. A day task list should reuse that surface instead of adding another floating panel.

## Decision

Each Planner day header exposes a compact planned-task list button. Pressing it opens the Planner's right-side sidebar for that date and shows a read-only task agenda derived from existing planner presentation data.

The agenda includes task-backed all-day planner items that intersect the selected date, followed by timed `DayPlanBlock` task blocks sorted by start time. Standalone events, Away, Sleep, Focus intervals, and other protected-session blocks stay out of the task list because they are not tasks planned through the Planner task-block model.

Opening an empty-slot action sidebar closes the day agenda, and opening the day agenda clears any temporary slot draft. The feature does not introduce new persistence, task planning semantics, or event/protected-session scheduling behavior.

## Consequences

- Users can inspect a date's planned task list without relying only on block positions in the grid.
- The right sidebar remains the Planner's stable secondary-content surface.
- The agenda count and sidebar contents follow the same visible planner snapshot as the grid.
