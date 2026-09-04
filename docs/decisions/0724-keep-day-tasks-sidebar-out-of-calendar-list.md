# 0724: Keep Day Tasks Sidebar Out of Calendar List

## Status

Accepted

## Date

2026-09-04

## Revises

- [0369: Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)
- [0529: Collapse Calendar List Planned Task Sections](0529-collapse-calendar-list-planned-task-sections.md)

## Refines

- [0288: Open Planned Day Task List From Planner Headers](0288-open-planned-day-task-list-from-planner-headers.md)
- [0674: Hide Flagged Tasks From Calendar List](0674-hide-flagged-tasks-from-calendar-list.md)

## Context

Calendar `List` already renders the same per-day task agenda that the focused
`Day Tasks` sidebar presents. Keeping an already-open Day Tasks sidebar visible
after entering List duplicates one selected day, reduces the width available
for comparing the visible day columns, and makes the sidebar look like an
additional List column.

The right companion area also serves independent purposes such as Filters,
`Go to date`, and task details. Removing the duplicate Day Tasks presentation
must not remove those useful List-mode routes.

## Decision

- The focused Day Tasks sidebar is available only in Calendar `Schedule`, where
  the day-header task button remains its entry point.
- Switching from Schedule to Calendar `List` dismisses an open Day Tasks
  sidebar together with the other Schedule-only interaction state.
- Calendar `List` suppresses Day Tasks presentation even if stale local
  selection state exists. Returning to Schedule restores access through the
  day-header button but does not automatically reopen the previous sidebar.
- Filters, `Go to date`, task-detail companions, and their existing mutual
  exclusion behavior remain available in List.
- The transition is presentation-only. It does not alter Calendar List rows,
  disclosure state, filters, Planner blocks, task history, or the persisted
  Schedule/List preference.

## Consequences

- Calendar List uses its available width for side-by-side day comparison
  instead of duplicating one day in Day Tasks.
- Schedule keeps the focused, draggable day agenda and its day-header access.
- Entering List has a deterministic one-way dismissal: returning to Schedule
  requires a deliberate day-header selection to reopen Day Tasks.
- Other right-side Planner and task-detail workflows continue to work in List.
