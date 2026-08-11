# 0544: Scope iOS Search Field to the Dedicated Search Tab

## Status

Accepted

## Date

2026-08-11

## Refines

- [0541: Keep iOS Search Input Ahead of Home Presentations](0541-keep-ios-search-input-ahead-of-home-presentations.md)

## Context

The iOS Search performance change attached the native searchable modifier to
the shared `TabView` so selecting Search would not replace the host. SwiftUI
therefore rendered its field above every tab, including Home, Timeline, and
More. The product already provides a dedicated Search destination in the
bottom tab bar, so those duplicate entry points were both confusing and
unnecessary.

## Decision

Attach the iOS searchable modifier to the already-retained Search tab's
content, not to the shared `TabView`. The Search tab retains the raw-input and
debounced-applied-query behavior from [0541](0541-keep-ios-search-input-ahead-of-home-presentations.md).
The `TabView` itself remains stable while the selected tab changes.

## Consequences

- Home, Timeline, More, and other non-Search tabs have no duplicate task
  search field.
- The bottom Search tab remains the single global task-search entry point.
- Search activation preserves the stable tab host and its typing-performance
  boundary.
