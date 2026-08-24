# 0658: Defer Mac Stats Tag Catalog to Searchable Pickers

## Status

Accepted

## Date

2026-08-24

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0548: Keep iOS Stats and Timeline Filter Details in Sheets](0548-keep-ios-stats-and-timeline-filter-details-in-sheets.md)
- [0579: Align iOS Filter Tag Picker With Task Tag Picker](0579-align-ios-filter-tag-picker-with-task-tag-picker.md)
- [0599: Separate Mac Stats Priority Filters](0599-separate-mac-stats-priority-filters.md)
- [0656: Make Mac All Filters Task-Ladder Complete and Searchable](0656-make-mac-all-filters-task-ladder-complete-and-searchable.md)

## Context

The Mac Stats sidebar rendered every available tag as inclusion chips, repeated
the applicable catalog as exclusion chips, and could add a separate related-tag
cloud between them. A large saved catalog therefore made Tags dominate the
sidebar even when no tag rule was active.

Mac `All` already established the calmer interaction: keep active rules visible
and defer browsing the catalog to a searchable picker.

## Decision

- Mac Stats presents one collapsible Tags card containing separate Include and
  Exclude rules.
- The ordinary card shows only active rule chips, or a clear empty state. The
  complete catalog and related suggestions are never rendered as inline chip
  clouds.
- `All` / `Any` matching appears only when its rule contains more than one tag.
- `Add tags…` and `Add tags to exclude…` open the same searchable Mac tag
  picker used by `All`, including pinned selections, bounded suggestions,
  counts, and a lazy Browse list.
- Existing Stats include/exclude matching, mutual exclusivity, persistence,
  counts, colors, and related-tag mutations remain unchanged.

## Consequences

- Stats remains compact regardless of the saved tag catalog size.
- People can still search or browse every tag deliberately and remove active
  rules directly from the card.
- Mac Stats and Mac `All` now use one predictable tag-filter interaction.
