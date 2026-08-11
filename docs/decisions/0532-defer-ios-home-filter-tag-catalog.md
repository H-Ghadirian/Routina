# 0532: Defer the iOS Home Filter Tag Catalog

## Status

Accepted

## Date

2026-08-11

## Refines

[0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md) for the iOS Home Filters sheet.

## Context

iOS Home Filters rendered every saved tag twice as wrapping chip layouts: once
for inclusion and again for exclusion. Building the required tag summaries
scanned the complete Home display set, and the long chip views made normal
filter-sheet scrolling hitch as a catalog grew.

## Decision

The iOS Home Filters sheet shows one compact `Tags` entry with only the current
include/exclude selection counts. It must not construct the complete tag
catalog while the main filter sheet is presented or scrolled.

Opening that entry presents a dedicated searchable Tag picker. The picker
prepares its catalog only after deliberate user interaction, filters it when
the query or catalog changes, and renders one virtualized native List row per
tag. It retains the current `All`/`Any` matching controls and can edit either
the include or exclude rule without dismissing.

## Consequences

- Normal Home Filter scrolling stays independent of saved-tag catalog size.
- People can still discover, search, select, and remove every tag from the
  focused picker.
- Expensive tag-summary work happens at the explicit picker-opening boundary,
  not within the scrolling parent sheet.
