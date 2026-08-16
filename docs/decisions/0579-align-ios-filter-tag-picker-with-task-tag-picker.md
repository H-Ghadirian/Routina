# 0579: Align iOS Filter Tag Picker With Task Tag Picker

## Status

Accepted

## Date

2026-08-16

## Refines

- [0531: Keep iOS Task Tag Selection Compact and Searchable](0531-keep-ios-task-tag-selection-compact-and-searchable.md)
- [0533: Keep Active iOS Filter Tag Rules Visible](0533-keep-active-ios-filter-tag-rules-visible.md)
- [0537: Keep All iOS Home Filter Options in Persistent Sheets](0537-keep-all-ios-home-filter-options-in-persistent-sheets.md)

## Context

Add Task uses a large-title searchable list in which an unselected tag has a
plus, a selected tag has a filled check, and every tag occupies one predictable
row. Filter Tags instead used an inline title, a separate selected-tags section,
and a second catalog section that repeated the same selected rows. The duplicate
presentation made a simple selection task feel denser and less direct.

Filter Tags still needs semantics that task assignment does not have: a tag can
show or hide tasks, and multiple tags can match with `All` or `Any`. It also
needs to preserve the active-rule visibility established by Decision 0533.

## Decision

iOS Home, Stats, and Timeline Filter Tags use the same large-title, searchable
plus/check row pattern as the Add Task tag picker. One unified catalog presents
each tag once. Active rules are pinned first, with hidden rules before included
rules, and state their `Hidden` or `Included` effect. Tapping an active row
removes that rule regardless of the currently chosen rule; tapping an
unselected row adds it to the current Show or Hide rule.

Show/Hide and `All`/`Any` remain explicit controls above the catalog. Searching
narrows only unselected catalog rows so all active rules remain visible and
directly removable. Catalog and selection presentation is rebuilt only when
the search, catalog, rule, or selected sets change, never from a scrolling row.

## Consequences

- Tag selection looks and behaves consistently between task editing and filters.
- Active rules remain discoverable without rendering the same tag twice.
- Moving a tag from Show to Hide, or the reverse, is deliberate: first remove
  the active rule, then add the tag under the other rule.
- Filter-specific matching semantics stay available without dominating the tag
  list.
- Home's primary Filters sheet continues to defer the full catalog until the
  dedicated picker opens.
