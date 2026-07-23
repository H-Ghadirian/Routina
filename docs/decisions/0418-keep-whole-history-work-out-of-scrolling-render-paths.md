# 0418: Keep Whole-History Work Out of Scrolling Render Paths

## Status

Accepted

## Date

2026-07-23

## Context

SwiftUI can reevaluate parent bodies, builders, and computed properties many times while a native list scrolls. A value that looks like a harmless computed property can therefore become frame-by-frame work.

Production profiling of Mac Planner Timeline found that scroll transactions repeatedly rebuilt the complete Timeline: SwiftData-backed task and log properties were read, all history was filtered and sorted more than once, entries were grouped by day, and row-number dictionaries were recreated even though only a few rows were visible. Lazy row rendering could not help because the expensive work happened before the list received its sections.

The visible symptom was slow, laggy scrolling. The important lesson is broader than Timeline: any unbounded history, Stats, Planner, or task-list derivation can cause the same failure when it is reached from `body`.

## Decision

Scrolling render paths must consume stable presentation snapshots. Work proportional to the complete data set belongs at explicit data/filter/search/preference invalidation boundaries, not in view bodies or row and section builders.

A snapshot should own all derived values that come from the same source, including visible entries, any unfiltered comparison set, grouped sections, counts, lookup tables, and row numbering. Repeated consumers must share that snapshot instead of independently invoking domain filtering or collection scans.

Snapshot caches must:

- use signatures or explicit invalidation that cover every input affecting visible output;
- preserve correctness when model data, filters, search, calendar semantics, attachments, or feature visibility changes;
- retain the last valid immutable snapshot during active macOS scrolling when a refresh would otherwise interrupt the gesture;
- apply deferred refreshes after the established scroll quiet window;
- avoid container identity churn that defeats native list virtualization and scroll-position preservation.

SwiftData queries and feature loading should continue moving behind the reducer boundary described by [0417](0417-route-feature-data-loading-through-reducers.md). Regardless of where data is loaded, views must not repeatedly transform the full model graph during scrolling.

Meaningful changes to unbounded scrolling surfaces require production-like performance verification:

1. Use enough history to expose work that scales with total records.
2. Use a Release build when evaluating user-visible smoothness.
3. Profile during continuous scrolling rather than relying only on visual intuition.
4. Inspect main-thread samples for repeated app-owned fetching, filtering, sorting, grouping, formatting, or model-property access.
5. Add a regression test for the architectural boundary when practical.

## Consequences

- Timeline, Planner, Stats, and other long lists pay whole-data-set costs when their inputs change, not once per scroll/layout transaction.
- Lazy containers can perform their intended job because data preparation no longer defeats row virtualization.
- Sync and persistence updates may wait briefly for active scrolling to become quiet, but they are not discarded.
- Presentation caches require careful signatures and invalidation; missing an input can show stale data, while invalidating too broadly can reintroduce hitches.
- Code review must treat convenience computed properties reached from `body` as potentially hot, even when their declaration is far from the visible list.
