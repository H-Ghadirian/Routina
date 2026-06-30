# 0319: Open Planner Filters in the Home Filter Pane

## Status

Accepted

## Date

2026-07-01

## Refines

- [0289: Filter Planner Calendar Layers](0289-filter-planner-calendar-layers.md)
- [0291: Gate Planner Calendar Filter Options by Beta Toggles](0291-gate-planner-calendar-filter-options-by-beta-toggles.md)
- [0309: Show Full Timeline in Planner List Mode](0309-show-full-timeline-in-planner-list-mode.md)
- [0312: Move Mac Task and Timeline Filter Entry to Toolbar](0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)

## Context

Mac Home had two filter entry points: a top toolbar filter button for Home task-list and Timeline filters, and a Planner header filter button for calendar layers. That split made the toolbar busier and made Planner List mode lose an obvious way to reach filters, even though Planner List uses the same Timeline-style filter state as the Timeline surface.

The Planner header already has a compact filter button beside the date/range utility control in Calendar mode. Keeping filter entry local to Planner preserves the user's current workspace and gives List mode a nearby filter affordance without reintroducing a top toolbar icon.

## Decision

Mac Home removes the top toolbar command-row filter icon. The centered search field, Focus controls, mode strip, Add controls, Places when enabled, and optional Progress controls remain in the toolbar command row.

The Planner header filter button remains visible in Calendar mode and is also visible in Planner List mode. Pressing it opens the existing right-side Home filter companion pane and selects a new top-level `Calendar` scope. The companion pane scope picker is now `Both` / `Task List` / `Timeline` / `Calendar`.

The `Calendar` scope owns the presentation-only Planner calendar layer toggles for planned tasks, all-day tasks, timeline suggestions, Events when Mac Event/Emotion actions are enabled, Focus, and Away/Sleep when `Show Away` is enabled. These toggles keep the same non-mutating semantics and beta availability normalization as the old Planner calendar filter sidebar.

Planner List remains a full Timeline-style list and is not scoped by calendar date or calendar layer filters. In List mode, the Planner header filter button still opens the companion pane so users can adjust shared `Both` filters, Timeline filters that affect visible List rows, Task List filters, or Calendar layer filters before returning to Calendar mode.

Planner's internal right sidebar is no longer used for calendar filters. It remains the surface for slot actions, day planned-task lists, and date selection. Opening the Home filter companion pane keeps the established mutual-exclusion rule with task-detail companion panes, the board inspector, and Planner internal sidebars.

## Consequences

- The top toolbar is quieter and no longer has a separate Home filter icon.
- Planner has one local filter entry point in both Calendar and List modes.
- Task-list, Timeline, shared, and calendar-layer filters share one companion-pane frame while keeping their existing data semantics.
- Calendar layer filters stay presentation-only and do not alter Planner List range, task data, events, sessions, or stored planner blocks.
