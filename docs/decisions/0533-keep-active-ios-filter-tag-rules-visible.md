# 0533: Keep Active iOS Filter Tag Rules Visible

## Status

Accepted

## Date

2026-08-11

## Refines

[0532: Defer the iOS Home Filter Tag Catalog](0532-defer-ios-home-filter-tag-catalog.md).

## Context

The compact iOS Home Filters Tags entry reported only counts such as `1 hidden`.
That made an active filter's meaning unclear. The deferred Tag picker always
opened on Show, so a person with only hidden tags had to switch to Hide or
search through the catalog to discover which tag was active.

## Decision

The compact Tags entry names the first active tag for each rule, prioritizing
the Hide rule, and appends a compact remainder count only when needed.

The Tag picker opens on Hide whenever an exclusion is active. Independently of
the current Show/Hide catalog, it keeps a `Selected tags` section at the top
that names every active inclusion and exclusion, labels its effect, and lets
the person remove it directly.

## Consequences

- A filter's active tag is immediately understandable before and after opening
  the picker.
- People do not need to remember which catalog tab contains their current
  selection or search just to inspect it.
- The compact entry and selected-rules list still work only from the small
  selected-tag sets; the full catalog remains deferred until picker opening.
