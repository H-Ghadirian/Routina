# 0021: Keep Mac Places in the Home Split Shell

## Status

Accepted

## Date

2026-05-11

## Supersedes

[0020: Show Mac Places as a Workspace](superseded/0020-show-mac-places-as-workspace.md)

## Context

Moving Places into a separate root workspace fixed some map/titlebar pressure, but it made the rest of the Mac window feel unstable. The left sidebar no longer behaved like Details, Planner, and Board; the root detail picker moved when selecting Places; and toolbar counters shifted because the app swapped out the normal `NavigationSplitView` shell.

The product expectation is that Places is another mode in the same Home window, not a different window architecture.

## Decision

Mac Home keeps one shared split-view shell for Details, Planner, Board, and Places. The root `Details / Planner / Board / Places` picker stays in the same detail-column header for all modes. When Places is selected, the sidebar keeps the shared Mac mode strip at the top, then replaces the task filters and task list below it with place check-in controls, saved places, and day timeline review. The detail column renders the map itself. The normal Mac sidebar remains expandable and collapsible through the system split-view controls.

Selecting Places from the segmented picker does not change the user's current sidebar mode or task-list filter. The quick check-in dock can still jump to Places, but it only changes sidebar mode when needed to get back into the normal Home split shell.

## Consequences

- The left sidebar behaves consistently across all four detail modes.
- The segmented picker no longer jumps because the root view hierarchy is not swapped.
- Toolbar counters stay in the normal Home toolbar layout when the sidebar is collapsed.
- The Places sidebar keeps the same top-level mode navigation as the other Home sidebar modes.
- Places uses the sidebar for current-location controls, saved places, and the day timeline, leaving the detail column map-first.
