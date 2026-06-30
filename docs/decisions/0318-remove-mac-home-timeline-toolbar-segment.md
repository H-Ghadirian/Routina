# 0318: Remove Mac Home Timeline Toolbar Segment

## Status

Accepted

## Date

2026-06-30

## Refines

- [0309: Show Full Timeline in Planner List Mode](0309-show-full-timeline-in-planner-list-mode.md)
- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)

## Context

Planner List mode now shows the full Timeline inside the primary Planner surface. Keeping a separate Timeline segment in the Mac Home toolbar made the toolbar offer two nearby routes to the same timeline review job: Planner `List` in the main area and Timeline in the left sidebar.

The Planner route is the clearer default because it keeps the timeline in the primary work area and preserves the Calendar/List switch as the local Planner display choice.

## Decision

Mac Home removes Timeline from the visible toolbar mode strip. The visible strip keeps Tasks, Goals when enabled, Adventure when enabled, Stats, Settings, and Add.

The Timeline model and filters remain available for Planner List, search, existing detail routing, and compatibility with note/event deep links. Commands or legacy actions that ask to open Timeline should route to Planner with `List` selected instead of opening the old Timeline sidebar as a visible toolbar destination.

## Consequences

- The toolbar no longer shows a redundant Timeline segment beside the Tasks segment.
- Users review the full timeline through Planner `List`.
- Existing Timeline filtering state and note/event detail selection can remain data-compatible while normal navigation moves through Planner.
