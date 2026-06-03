# 0020: Show Mac Places as a Workspace

## Status

Superseded

## Date

2026-05-10

## Supersedes

[0019: Show Mac Places as a Detail Mode](0019-show-mac-places-as-detail-mode.md)

## Superseded By

[0021: Keep Mac Places in the Home Split Shell](../0021-keep-mac-places-in-home-split-shell.md)

## Context

Places needs to combine live check-in, saved places, map navigation, and day timeline review. Keeping that surface inside the task `NavigationSplitView` detail column made the map compete with the task sidebar, the detail-mode picker, and macOS toolbar/titlebar safe areas.

Several local spacing fixes still left the map and sidebar sensitive to window chrome and MapKit layout behavior. The underlying problem was structural: Places is not a task detail state.

## Decision

Mac Home treats Places as a first-class workspace selected by the root `Details / Planner / Board / Places` picker. Details, Planner, and Board continue to use the task sidebar split view. Places replaces that split view with its own workspace: a control/timeline panel beside a full-height map.

The check-in dock lives in the Mac sidebar bottom safe area and switches into the Places workspace instead of opening a sheet or rendering a map inside task detail. The dock is hidden while Places is active because check-in controls are owned by the workspace itself.

## Consequences

- Places no longer depends on task sidebar layout, task detail selection, or split-view safe-area fixes.
- The quick check-in dock is scoped to the visible sidebar and does not float over Planner, Board, or a collapsed-sidebar layout.
- The root detail-mode picker remains stable and outside the MapKit surface.
- The map can fill its workspace and keep zoom/location controls locally scoped.
- Switching back to Details, Planner, or Board restores the existing task split-view experience.
- iPhone and watch check-in presentation behavior remains platform-owned and unchanged.
