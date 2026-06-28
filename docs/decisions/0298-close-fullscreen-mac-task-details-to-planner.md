# 0298: Close Fullscreen Mac Task Details to Planner

## Status

Accepted

## Date

2026-06-28

## Refines

- [0021: Keep Mac Places in the Home Split Shell](0021-keep-mac-places-in-home-split-shell.md)
- [0022: Own Mac Home Toolbar at Split Shell](0022-own-mac-home-toolbar-at-split-shell.md)
- [0276: Open Mac Home to Planner](0276-open-mac-home-to-planner.md)
- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)
- [0297: Open Mac Task Rows Fullscreen on Double Click](0297-open-mac-task-rows-fullscreen-on-double-click.md)

## Context

Planner is the primary Mac Home workspace. The top `Details / Planner` segmented control made the Planner relationship feel like a persistent mode switch even after task details moved into an inspector-first flow. Full task details still need to be available for explicit opening, but leaving that surface should return to Planner instead of requiring a global mode picker.

## Decision

Mac Home no longer shows a top detail-mode segmented control for `Details / Planner`. Details remains reachable through explicit task-detail routes such as companion-pane fullscreen, task double-click, deep links, and other task-opening actions.

When a task is opened in the full Details surface, the task-detail toolbar shows a close control on the top right. Closing full Details clears any task-detail companion pane state, keeps the selected task intact, and returns the Home detail area to Planner.

Planner-specific right sidebars and the task-detail companion pane keep their existing mutual-exclusion behavior. This change does not alter task, planner-block, event, focus, Away, Sleep, or persistence models.

## Consequences

- Planner remains the visible default workspace without a permanent `Details / Planner` switch in the toolbar.
- Full task detail remains an explicit route rather than a global top-level mode users need to manage.
- Users leave full task detail with a close button in the task-detail toolbar.
- Selected task state is preserved when returning from full Details to Planner.
