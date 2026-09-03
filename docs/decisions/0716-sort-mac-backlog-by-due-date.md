# 0716: Sort Mac Backlog by Due Date

## Status

Accepted

## Date

2026-09-03

## Revises

- [0690: Place Mac Filters Beside Planner and Backlog Workspaces](0690-place-mac-filters-beside-planner-and-backlog-workspaces.md)

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Backlog's Mac companion surface could narrow its task collection but deliberately omitted sorting. The cached Backlog presentation nevertheless used an implicit row order, and a person reviewing deferred work had no direct way to make upcoming deadlines the primary comparison. The filter-only title also stopped describing the surface once ordering became a deliberate choice.

Due date has two product meanings that belong in the same order: a one-time task's explicit deadline and a repeating Due routine's next occurrence. Gentle routines and tasks without an actual due boundary should not be assigned a synthetic date merely to participate in the sort.

## Decision

- The Mac Backlog companion and fullscreen surface is titled `Filter and Sort`.
- Backlog task order offers `Default`, `Due Soonest`, and `Due Latest`. Default preserves the established Backlog ordering.
- Due-date ordering applies independently inside each Backlog super section, subsection, and the automatic `Hidden by flag` group. It does not reorder the durable section hierarchy or the separate search results found outside Backlog.
- A sortable due boundary is the explicit deadline of a one-time task or the next due occurrence of a repeating Due routine. Gentle routines, cadence-free routines, and one-time tasks without a deadline remain after dated tasks for either due direction.
- The explicit due date is the primary comparison, so a later pinned task does not outrank an earlier due task. Existing Backlog ordering breaks equal-date and undated ties.
- Sorting changes presentation only. It does not move a task, rewrite a path, alter a schedule, or prune deliberately empty sections. Filter-driven hierarchy pruning remains independent.
- Sort state remains independent, in-memory Backlog state. A non-default order marks the workspace toolbar action active, and Reset restores both filters and sort order.
- Due-boundary derivation and sorting happen only while the reducer rebuilds the cached Backlog presentation. SwiftUI row and section builders continue consuming the stable snapshot.

## Consequences

- A person can review the most imminent or farthest due Backlog work without reorganizing it.
- One-time and repeating Due work participate in a consistent ordering, while Gentle and undated work is not misrepresented as due.
- Empty Backlog destinations remain usable when sort is the only non-default choice.
- The pane title, active indicator, and reset behavior describe both kinds of presentation control.
