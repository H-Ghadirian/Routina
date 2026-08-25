# 0243 — Cache cross-surface filter membership

Date: 2026-08-24

## Symptom

Planner Calendar could repeatedly filter every task and derive current Task
Ladder values while SwiftUI reevaluated the calendar during scrolling.

## Root Cause

The shared filter was passed as a closure and applied directly to the complete
render-snapshot task array in `body`. Its existing seed invalidated downstream
day-list caches but did not cache the filtered task collection itself.

## Fix

A dedicated cache now owns the filtered task array plus complete and matching
task ID sets, keyed by the Planner data snapshot and shared-filter/day seed.

## Prevention Rule

When a cross-surface filter touches a complete collection, cache both the
filtered collection and related lookup sets at the same invalidation boundary;
do not leave a full-array filter in a scrolling render path.

## Regression Safeguard

`Tests/macOS/PerformanceRegressionTests.swift` requires the cache boundary and
rejects the former direct render-snapshot filter. See [Decision 0660](../decisions/0660-make-mac-planner-filters-explicit-composable-and-bounded.md).
