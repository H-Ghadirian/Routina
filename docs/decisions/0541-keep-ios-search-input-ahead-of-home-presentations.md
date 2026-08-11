# 0541: Keep iOS Search Input Ahead of Home Presentations

## Status

Accepted

## Date

2026-08-11

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0502: Keep Mac Task Forms and Search Input Frame-Safe](0502-keep-mac-task-forms-and-search-input-frame-safe.md)

## Context

iOS Search passed every keystroke directly into Home's task-list presentation
token. Each input update could rebuild a full filtered, sectioned task-list
snapshot while the keyboard was trying to deliver the next character. Search
selection also conditionally added the searchable modifier to the entire tab
host, replacing that host while its search animation and keyboard presentation
were starting.

## Decision

iOS Search retains one stable tab host regardless of the selected tab. Its raw
search text stays bound directly to the native searchable control, while the
Home Search destination receives a separately applied query. Non-empty input
updates that query after a 120-millisecond idle debounce; clearing applies
immediately. A cancelled or superseded debounce must not publish stale results.

## Consequences

- Search activation does not replace the tab hierarchy during its animation.
- Rapid typing stays ahead of whole-list filtering and section construction.
- Search results settle shortly after a typing burst, while clearing restores
  the normal Home presentation without a delay.
- Future iOS search surfaces that drive unbounded presentations must preserve
  this raw-input/applied-query boundary.
