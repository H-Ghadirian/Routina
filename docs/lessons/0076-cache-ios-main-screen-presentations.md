# 0076 — Cache iOS main-screen presentations

Date: 2026-08-03

## Symptom

The iOS Home, Timeline, Planner, Goals, and Stats screens lagged during ordinary interaction, and their long lists did not scroll smoothly as history and task volume increased.

## Root Cause

Several SwiftUI render paths rebuilt work proportional to the complete data set. Home regenerated filtered and sectioned task presentations and attachment tokens, Timeline flattened entries and repeatedly scanned raw record arrays for row data, Planner built four full-history change-token arrays twice per render, Goals searched and counted linked tasks from computed properties, and Stats derived assignment collections from queries inside its view hierarchy. Repeated row decorations also used effects intended for bounded surfaces.

## Fix

Each feature now builds immutable presentation artifacts only when source data or semantic filters change. The views consume cached sections, stable IDs, row-number offsets, lookup dictionaries, tag options, goal summaries, and prefiltered focus-assignment collections. Planner lifecycle refreshes use its existing scalar data-snapshot revision and are owned by one surface. Unbounded iOS rows use lightweight scrolling fills for noninteractive decoration, and broad SwiftData queries used only for active-state checks were narrowed.

## Prevention Rule

Treat every value reached from an iOS scrolling `body` or row builder as frame-budgeted work. Complete-collection filtering, grouping, sorting, flattening, lookup construction, and persistence fetches belong at explicit data or filter invalidation boundaries; rows should receive already-indexed values and stable semantic IDs.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests` protects the Home, Timeline, Planner, Goals, and Stats snapshot boundaries and rejects the specific full-collection render-path patterns that caused this regression. Decisions [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md) and [0419](../decisions/0419-use-lightweight-surfaces-inside-unbounded-scroll-rows.md) remain the governing design rules.
