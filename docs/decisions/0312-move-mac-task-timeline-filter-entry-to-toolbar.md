# 0312: Move Mac Task and Timeline Filter Entry to Toolbar

## Status

Accepted

## Date

2026-06-28

## Refines

- [0216: Move Mac Home Task Type Tabs to Filter Screen](0216-move-mac-home-task-type-tabs-to-filter-screen.md)
- [0289: Filter Planner Calendar Layers](0289-filter-planner-calendar-layers.md)
- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)

## Refined By

- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)
- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)

## Context

Mac Home had separate filter buttons for the task list and Timeline sidebar surfaces, while the Planner Calendar kept its own header filter button for calendar layers.

With search and global Home navigation now in the toolbar, task-list and Timeline filter entry points belong near the shared search field instead of repeating as surface-local sidebar buttons. Planner Calendar filters are different: they affect only visible calendar layers and are coupled to the Planner right sidebar's one-secondary-surface rule.

## Decision

Mac Home renders one filter button beside the toolbar search field for Home-level task-list and Timeline filters. Pressing it opens the Mac Home filter detail screen with a top-level `Both` / `Task List` / `Timeline` segmented picker. The picker defaults to `Timeline` when opened from the Timeline sidebar and to `Task List` otherwise.

Tags and importance/urgency are shared Home filters in the `Both` tab. Editing them there writes the selected tags, excluded tags, tag match modes, and importance/urgency threshold to both the task-list filter state and the Timeline filter state. The Task List tab keeps task-list-only controls such as task kind, created date, status, pressure, goals, media, places, sorting, and task-row appearance. The Timeline tab keeps Timeline-only controls such as type, status, media, and timeline-row appearance.

Mac Home Timeline filters do not expose or apply a range filter; Timeline stays all-range in the Home sidebar and Planner List's Timeline-style surface. Timeline type filters omit Sleep whenever the Sleep stats/timeline toggle is disabled, while preserving stored Sleep records and stale filter state compatibility by normalizing hidden Sleep selections back to `All`.

The toolbar filter button shows active state when either task-list or Timeline filters are active. Task and Timeline sidebar headers no longer render their own filter icon buttons; when filters are active, those headers may still show a compact clear action and active-filter summary.

Planner Calendar keeps its existing header filter button and right-side Planner sidebar filter screen from [0289](0289-filter-planner-calendar-layers.md). Calendar layer filters are not moved into the Home toolbar filter detail because they remain Planner-local presentation state and must continue to participate in the Planner right sidebar's mutual-exclusion behavior.

## Consequences

- Task-list and Timeline filters have one toolbar entry point beside shared search, with shared tag and priority filters centralized under `Both`.
- The sidebar stays quieter while preserving active-filter visibility and clearing.
- Mac Home Timeline filtering no longer has a visible or effective range option.
- Planner Calendar filtering remains discoverable in the Planner header and keeps its right-sidebar behavior unchanged.
