# 0548: Keep iOS Stats and Timeline Filter Details in Sheets

## Status

Accepted

## Date

2026-08-11

## Refines

- [0537: Keep All iOS Home Filter Options in Persistent Sheets](0537-keep-all-ios-home-filter-options-in-persistent-sheets.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Stats and Timeline still expanded their filter controls in the primary filter
sheet. In particular, a saved-tag catalog could make that sheet long and make
finding another filter cumbersome. iOS Home already uses a compact overview
that opens persistent, focused picker sheets.

## Decision

iOS Stats and Timeline Filters use the same compact-entry pattern as Home:
each available filter opens a dedicated sheet that remains open while its
selection changes. The primary sheet shows the current value for Range, Type,
Media, Query, and Tags where applicable; Priority keeps its specialized detail
sheet; Clear Filters remains a direct primary-sheet action.

Tags open the shared searchable picker only after the person selects the Tags
entry. The primary Stats and Timeline sheets must not render the full tag
catalog or a long inline tag list.

## Consequences

- Stats and Timeline filter sheets stay short as saved-tag catalogs grow.
- People can inspect the current selection before opening a focused control and
  make multiple changes before choosing Done.
- Tag catalog preparation remains outside the parent sheet's scrolling path.
