# 0343: Add Mac Home Sidebar Collapse Control

## Status

Accepted

## Date

2026-07-05

## Refines

- [0021: Keep Mac Places in the Home Split Shell](0021-keep-mac-places-in-home-split-shell.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

Mac Home already keeps Details, Planner, Board, Goals, and Places inside one shared split shell, and the left sidebar is expected to be collapsible through split-view behavior. The app also removes the native sidebar toggle from its custom top chrome, leaving users without an obvious in-app control for hiding or restoring the left sidebar.

## Decision

Mac Home provides an explicit leading toolbar control for the left sidebar. Pressing it drives the shared `NavigationSplitView` column visibility for the Home split shell, collapsing the sidebar to the detail column or expanding it back to the full split view. The control stays in the root-owned top toolbar so it remains available after the sidebar is hidden and applies consistently across Details, Planner, Board, Goals, and Places surfaces.

## Consequences

- Users can intentionally reclaim horizontal space without relying on hidden system split-view affordances.
- The toolbar remains the stable place for global Home chrome while the sidebar stays focused on surface-local lists and controls.
- The Home minimum window sizing still prevents unintentional responsive pane collapse; sidebar collapse is now an explicit user action.
