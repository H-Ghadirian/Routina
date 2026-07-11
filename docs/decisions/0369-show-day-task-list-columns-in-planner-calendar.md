# 0369: Show Day Task List Columns in Planner Calendar

Date: 2026-07-11

Status: Accepted

Refines: [0288 Open Planned Day Task List From Planner Headers](0288-open-planned-day-task-list-from-planner-headers.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0368 Hide Assumed-Done Calendar Layer by Default](0368-hide-assumed-done-calendar-layer-by-default.md)

## Context

Planner Calendar already exposes each date's task agenda from the day header into the right sidebar. That agenda is useful for checklist-style review, but users sometimes want to compare those day task lists across the whole visible range without opening a sidebar one date at a time.

The existing timed Planner Calendar remains the primary surface for slot editing, all-day drops, automatic activity placement, and time-of-day planning. A list-style task view should reuse the existing agenda data instead of introducing separate task grouping or persistence.

## Decision

Planner Calendar has a presentation-only `Schedule` / `List` segmented control. `Schedule` keeps the current timed calendar form, including the day-header task button that opens the right-side day agenda. `List` keeps the same visible date columns but hides that redundant day-header task button and replaces the timed grid, time labels, all-day lane, Needs Time lane, current-time indicator, and drag/drop slot layers with per-day task agenda columns.

The per-day columns render the same `Planned tasks`, `Assumed done`, and `Dones` sections used by the right-side day task sidebar. They follow the same Calendar search, task filters, timeline-suggestion visibility, hidden individual activity, and assumed-done summary behavior as the sidebar. Opening a task from the list uses the existing task-detail route. Switching to `List` clears schedule-only draft, drag, drop, and resize interaction state. Switching list presentation does not create, resize, move, confirm, hide, or delete Planner blocks or timeline activity.

## Consequences

- Users can compare day task lists across Day, 3 Days, and Week ranges without leaving Calendar mode.
- The right sidebar remains available for focused single-day review, filters, date selection, and slot actions.
- Schedule-specific interactions stay in `Schedule` mode, keeping `List` read-only and model-preserving.
