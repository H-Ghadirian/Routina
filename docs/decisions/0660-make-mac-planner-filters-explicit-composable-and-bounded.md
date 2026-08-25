# 0660: Make Mac Planner Filters Explicit, Composable, and Bounded

## Status

Accepted

## Date

2026-08-24

## Supersedes

- [0364: Rename Shared Mac Filter Scope to All](superseded/0364-rename-shared-mac-filter-scope-to-all.md)

## Revises

- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)
- [0656: Make Mac All Filters Task-Ladder Complete and Searchable](0656-make-mac-all-filters-task-ladder-complete-and-searchable.md)

## Refines

- [0256: Move Mac Timeline Row Appearance to Timeline Filter Detail](0256-move-mac-timeline-row-appearance-to-timeline-filter-detail.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

The Planner filter companion pane combined four different concepts under a
scope labeled `All`. That label looked like a request to show all filter
controls, even though the scope contained only filters shared by task-backed
Task List, Timeline, and Calendar rows. The picker also gave no indication
that another scope still had active filters.

Timeline presented Type and Status as separate controls while storing both in
one enum selection, so changing either control silently cleared the other.
Fullscreen expansion then stretched the narrow companion-pane design across
the whole window. In Planner Calendar, shared task membership was also
re-filtered from the complete task collection during SwiftUI body evaluation,
including current Task Ladder value derivation.

## Decision

- The shared scope is labeled `Shared`, followed by a concise explanation that
  it applies to task-backed rows in Task List, Timeline, and Calendar. Every
  scope segment shows a small active indicator when that scope owns an active
  filter.
- Mac Timeline stores content Type and task-outcome Status independently and
  applies both as an intersection. Status keeps its established task-history
  meaning: Done, Missed, and Canceled exclude standalone activity. Persisted
  legacy outcome selections migrate to content Type `All` plus the matching
  Status value.
- Fullscreen filter presentation centers the same filter surface within an
  840-point readable maximum instead of stretching pane-oriented segmented
  controls across the entire detail width. The 420-point companion pane keeps
  its existing layout.
- Planner Calendar caches shared-filter task membership by data snapshot and
  complete filter/day signature. SwiftUI body reevaluation reuses the cached
  task array and ID sets; current Task Ladder values and whole-task filtering
  run only when the source snapshot or filter signature changes.

## Consequences

- Scope names describe ownership instead of implying that every control is in
  one tab, and active filters in another scope remain discoverable.
- A person can combine Timeline choices such as Todos + Done without one
  selection resetting the other.
- Fullscreen remains useful for focus and scrolling without producing
  window-wide controls or sparse single-column cards.
- Planner Calendar scrolling no longer repeats shared task-filter and current
  Task Ladder derivation work for an unchanged snapshot.
