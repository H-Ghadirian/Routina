# 0018: Show Mac Map Check-In in the Detail Column

## Status

Superseded by [0019: Show Mac Places as a Detail Mode](0019-show-mac-places-as-detail-mode.md)

## Date

2026-05-10

## Supersedes

[0017: Show Mac Map Check-In Inline](0017-show-mac-map-check-in-inline.md)

## Context

The first Mac inline map check-in presentation kept the flow in the main window, but it still behaved like a floating bottom panel over the sidebar and detail content. That made it feel modal and visually competed with the timeline/sidebar layout.

## Decision

Mac Home presents map check-in as detail-column content. The bottom check-in dock remains a launcher, while the right side of the split view becomes the map, current-location controls, saved places, and day timeline until the user closes it.

## Consequences

- The map is part of the main Mac window layout instead of an overlay or pop-up.
- The sidebar remains available for context while the map owns the detail pane.
- Existing iPhone sheet behavior stays unchanged because the presentation choice remains platform-owned.
