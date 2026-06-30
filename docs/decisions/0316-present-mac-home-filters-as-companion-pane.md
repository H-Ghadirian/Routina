# 0316: Present Mac Home Filters as a Companion Pane

## Status

Accepted

## Date

2026-06-29

## Refines

- [0312: Move Mac Task and Timeline Filter Entry to Toolbar](0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)
- [0302: Minimize Fullscreen Mac Task Details to the Companion Pane](0302-minimize-fullscreen-mac-task-details-to-companion-pane.md)

## Refined By

- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)

## Context

[0312](0312-move-mac-task-timeline-filter-entry-to-toolbar.md) moved Home-level Task List and Timeline filters into one toolbar entry point. The first implementation opened that filter detail as the main detail screen, which hid the active Home workspace.

Mac Home now has an established right-side companion-pane pattern for secondary work. Users expect filter editing to behave like task details: open beside the current workspace, expand temporarily when more room is useful, then minimize back to the pane without losing context.

## Decision

The Mac Home toolbar filter button opens Home-level filters in a right-side companion pane inside the Mac detail area. The pane keeps the active workspace visible, preserves the current task selection, and owns close and fullscreen controls.

The fullscreen filter view uses the same `Both` / `Task List` / `Timeline` content but takes over the detail area only after the user explicitly expands it. A minimize control restores the previous right-side filter pane; closing dismisses the filter presentation.

Only one right-side secondary surface should occupy the Mac detail area at a time. Opening the Home filter pane hides task-detail companion panes and the board inspector, and Planner treats the Home filter pane as an external inspector so Planner-local sidebars dismiss. Opening Planner-local sidebars or task-detail routes can close the Home filter pane through the normal selection and sidebar routing paths.

Timeline automatic fallback selection remains deferred while the filter pane is open so filter edits do not unexpectedly select a row or close the pane. Explicit Timeline row selection can still proceed through the normal selection route.

Planner Calendar filters remain separate. They keep using Planner's internal right sidebar because those filters are Planner-local presentation state rather than Home-level Task List or Timeline filtering.

## Consequences

- Home-level filters can be adjusted without losing sight of Planner, Board, Timeline, Details, or Places.
- The filter pane follows the same close, fullscreen, and minimize-back pattern as task-detail companion panes.
- Existing Task List, Timeline, shared tag, and importance/urgency filter semantics remain unchanged.
- Planner-local filter behavior stays isolated from Home toolbar filters.
