# 0529: Collapse Calendar List Planned Task Sections

## Status

Accepted

## Date

2026-08-09

## Refines

- [0509: Collapse Calendar List Assumed-Done Sections](0509-collapse-calendar-list-assumed-done-sections.md)
- [0369: Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)
- [0448: Complete Planned Tasks Inline From Calendar List](0448-complete-planned-tasks-inline-from-calendar-list.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Calendar `List` is a compact comparison surface. A day can have many planned
rows as well as synthetic assumed-done rows. Showing either category in full
can push the next day’s summary out of view before a person chooses to review
its tasks.

The existing assumed-done disclosure already keeps that activity available
without changing the cached day-task presentation. Planned rows need the same
presentation-only control while retaining their inline completion action when
they are expanded.

## Decision

On macOS, each non-empty `Planned tasks` and `Assumed done` section in Calendar
`List` has a full-width disclosure header that keeps its title and count
visible. Both types start collapsed by default. A header selection expands or
collapses only that section for that day, so a person can review planned work
without also expanding assumptions, or vice versa.

Settings -> Calendar -> Calendar List provides one `Collapsed` / `Expanded`
default for newly shown Planned tasks and Assumed done sections. The existing
stored preference is retained for continuity; changing it does not undo an
explicit disclosure choice during the current Calendar List view.

The right-side day-task sidebar remains expanded and unchanged. Disclosure
state controls only row rendering after the existing cached day-task
presentation is available: it does not filter data, alter counts, change
completion behavior, mutate Planner records, or repeat Planner grouping while
columns scroll.

## Consequences

- Dense planned days remain scannable while preserving one-click access to
  planned work and its existing inline completion action.
- Planned and assumed-done review can be expanded independently in the same
  day column.
- Existing Calendar List default and backup/import behavior continues without
  a preference migration.
- The established presentation-snapshot and list-virtualization boundaries
  remain intact.
