# 0690: Place Mac Filters Beside Planner and Backlog Workspaces

## Status

Accepted

## Date

2026-08-28

## Revises

- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)

## Refines

- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md)
- [0634: Unify Mac Workspace Search and Creation](0634-unify-mac-workspace-search-and-creation.md)
- [0660: Make Mac Planner Filters Explicit, Composable, and Bounded](0660-make-mac-planner-filters-explicit-composable-and-bounded.md)

## Context

[0319](0319-open-planner-filters-in-home-filter-pane.md) removed the Mac top-toolbar filter entry and kept a Planner-local header button. After Backlog became an integrated main-window workspace, that placement no longer communicated that filtering is a workspace-level action, and Backlog had no equivalent way to narrow its hierarchy without changing its organization.

Planner and Backlog also need different filter meanings. Planner composes the established `Shared`, `Task List`, `Timeline`, and `Calendar` scopes. Backlog needs filters over the tasks it owns, not Planner layers, Timeline outcomes, task-list visibility settings, appearance, grouping, or sorting controls.

Placing the conditional button to the right of the workspace menu made the persistent menu shift horizontally whenever Filters disappeared. The optional action therefore belongs on the menu's left, preserving a stable trailing anchor for the control that remains available across workspaces.

## Decision

- The Mac top toolbar shows one filter button immediately to the left of the combined workspace-and-actions menu only while Planner or Backlog is active. The workspace menu stays at the trailing edge of this command cluster, so hiding the conditional filter in other workspaces does not make the workspace control jump. Task Ladder, Stats, Settings, Details, and every other workspace omit the filter.
- Planner removes its local header filter button. The toolbar button opens the existing companion/fullscreen filter surface and retains the established `Shared`, `Task List`, `Timeline`, and `Calendar` scopes and Calendar-default opening behavior.
- Backlog uses the same companion-pane, fullscreen, minimize, and close presentation pattern, but owns independent in-memory filter state. Its controls cover task type, one-time status, created date, current Importance/Urgency, minimum Pressure, Thinking needed, estimate presence, media presence, Tags, and Flags.
- Backlog deliberately omits Planner Calendar layers, Timeline content/outcome filters, task-list visibility and appearance controls, grouping, and sorting. Backlog filters change only its current presentation; they do not move tasks, rewrite paths, or mutate task data.
- Backlog filter catalogs come from the complete unfiltered set currently owned by Backlog. The reducer rebuilds the cached Backlog presentation when data, search, or Backlog filter state changes, so SwiftUI row and section builders do not walk or re-filter the complete task collection.
- Without an active Backlog filter, deliberately created empty super sections and subsections remain visible and reachable. While any Backlog filter is active, cached presentation construction omits each subsection with no matching task and each super section with neither a direct match nor a matching subsection. Clearing filters restores the normal hierarchy, including intentionally empty sections.
- Backlog search stays globally duplicate-aware even when an active Backlog filter hides a matching Backlog row. Filter-hidden Backlog tasks do not become `Found outside Backlog` results and do not enable duplicate creation.
- The toolbar icon indicates when the active workspace owns any non-default filter and remains a full-surface clickable button.

## Consequences

- Filter placement consistently reads as an action for the active Planner or Backlog workspace without adding irrelevant toolbar chrome elsewhere.
- The persistent workspace control keeps one stable trailing position as the conditional filter appears or disappears on its left.
- Planner keeps its existing filter behavior while recovering header width for planning controls.
- Backlog can be narrowed without pretending that Planner-specific layer and appearance choices apply to it.
- Filtered Backlog results contain only hierarchy that explains a visible match, while the unfiltered workspace remains useful for creating into empty destinations.
- Backlog filters reset with the Backlog feature state rather than becoming synchronized or durable preferences.
- Search, filtering, and Backlog ownership remain separate concepts, and expensive derivation stays at the cached presentation boundary.
