# 0155 — Cache sidebar filter-summary counts

Date: 2026-08-13

## Symptom

On a large Mac Home task list, scrolling could repeatedly evaluate the sidebar
filter summary and add avoidable task-by-task work to the render path.

## Root Cause

The summary calculated its result count with a fresh `sidebarVisibleTaskCount`
pass over every active, away, and archived display even though the cached
task-list presentation had already filtered those same inputs.

## Fix

The immutable `HomeTaskListPresentation` now stores its visible count when it
is built. The Mac summary reads that cached value from the current presentation
instead of reconstructing a filtering helper and scanning all displays.

## Prevention Rule

Any count, grouping, lookup, or display copy derived from a scrolling task
list must be stored with its presentation snapshot. Do not add a convenience
whole-collection pass to a SwiftUI body, toolbar, sidebar, row, or section
builder.

## Regression Safeguard

`PerformanceRegressionTests.testMacSidebarFilterSummaryUsesCachedTaskListPresentation`
asserts that the sidebar uses the cached presentation count and cannot call
`sidebarVisibleTaskCount` directly. Decision
[0560](../decisions/0560-cache-sidebar-filter-summary-counts.md) records the
durable performance boundary.
