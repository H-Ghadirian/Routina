# 0311: Move Mac Home Mode Strip to Toolbar

## Status

Accepted

## Date

2026-06-28

## Refines

- [0022: Own Mac Home Toolbar at the Split Shell](0022-own-mac-home-toolbar-at-split-shell.md)
- [0278: Open Single Mac Add Action Directly](0278-open-single-mac-add-action-directly.md)
- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)

## Refined By

- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)
- [0318: Remove Mac Home Timeline Toolbar Segment](0318-remove-mac-home-timeline-toolbar-segment.md)

## Context

Mac Home's primary mode strip for Tasks, Timeline, Goals, Stats, Settings, and Add lived at the top of the left sidebar. That made global navigation depend visually on the sidebar area even though Home's other global controls, including search and Focus Timer, live in the root-owned toolbar.

The sidebar should stay focused on the active surface's list, filters, form sections, or utility controls. The top toolbar is the steadier place for app-wide Home navigation because it remains visible next to the Focus Timer and search controls.

## Decision

Mac Home renders the primary Home mode strip as a compact toolbar control beside the Focus Timer branch. The strip keeps the same visible mode gating for Goals and Adventure, the same selected-mode binding, and the same Add behavior: a single visible Add action opens directly, while multiple visible Add actions are presented as a menu.

The left sidebar no longer renders the primary mode strip. Sidebar headers may continue to render surface-local controls such as task-list mode filters, search/filter panels, form section navigation, Places controls, and status composition.

## Consequences

Global Home navigation remains available in the titlebar area even as the sidebar content changes.

Future sidebar work should not reintroduce the primary Home mode strip into sidebar headers. Future toolbar work should preserve the strip near search and Focus Timer while keeping the Focus Timer active/start/disabled branch mutually exclusive.
