# 0723: Filter Mac Backlog by Due Status

## Status

Accepted

## Date

2026-09-04

## Revises

- [0690: Place Mac Filters Beside Planner and Backlog Workspaces](0690-place-mac-filters-beside-planner-and-backlog-workspaces.md)
- [0721: Customize Mac Backlog Row Appearance](0721-customize-mac-backlog-row-appearance.md)

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0716: Sort Mac Backlog by Due Date](0716-sort-mac-backlog-by-due-date.md)

## Context

Backlog could sort tasks by their true due boundary, but its Filter tab could not remove undated work or isolate work due today or already overdue. Sorting therefore helped compare deadlines without supporting a focused review of only deadline-bearing or late work.

Due meaning must stay aligned with existing task semantics. A one-time task has a due boundary only when it has an explicit deadline. A repeating task has one only when it uses active Due cadence; Gentle and cadence-free routines must not be presented as due or overdue. Day-relative choices also need to update when the local calendar day changes while Backlog remains open.

## Decision

- Mac Backlog's Filter tab adds one `Due` row with `All`, `Has Due Date`, `Due Today`, and `Overdue` choices.
- `Has Due Date` includes every active Backlog task with a true due boundary, whether that boundary is past, today, or future. `Due Today` includes a boundary on the current local calendar day. `Overdue` uses Routina's established full-calendar-day overdue calculation.
- A true due boundary is the same value used by Backlog due sorting: a one-time deadline or the next occurrence of an active repeating Due task. Undated one-time tasks, Gentle routines, and cadence-free routines do not match any non-All choice.
- Due filtering composes with every other Backlog filter and search term. It prunes empty Backlog hierarchy through the existing cached presentation without changing task placement, section order, schedules, or duplicate-aware search behavior.
- Due filter state remains transient Backlog state. Reset restores `All` alongside the other filters and sort order.
- While `Due Today` or `Overdue` is selected, the feature schedules a cached presentation rebuild at the next local day boundary and reschedules while Backlog remains active. Closing Backlog cancels that refresh.
- Due-boundary derivation happens while rebuilding the reducer-owned presentation. Scrolling row builders continue consuming cached results.

## Consequences

- A person can review all deadline-bearing Backlog work, today's due work, or only overdue work without moving tasks or hiding undated work permanently.
- One-time and repeating Due tasks keep consistent meanings across filtering, sorting, row metadata, and Task Details.
- The visible hierarchy and toolbar active state accurately reflect a selected Due filter.
- Long-running Backlog sessions cross midnight without retaining yesterday's Due Today or Overdue membership.
