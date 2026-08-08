# 0110 — Cache Home row numbers outside List builders

Date: 2026-08-08

## Symptom

With a seeded iOS store containing hundreds of tasks and more than a thousand timeline records, extended Home list traversal could make the UI-test accessibility driver wait on the app's main run loop while users would be scrolling.

## Root Cause

`HomeIOSTaskListView` rebuilt visible section and group row-number offsets from the complete Home presentation inside its `List` builder. SwiftUI can reevaluate that builder during scrolling, so the work scaled with the full task presentation instead of the visible rows.

## Fix

Home now computes visible row numbers in an invalidation-driven cache when the presentation, search state, or collapsed-section preferences change. Row builders only perform a dictionary lookup.

## Prevention Rule

Never derive row offsets, row numbers, grouping, filtering, or other whole-list artifacts from a scrolling `List` or row builder. Build them at a presentation invalidation boundary and pass the immutable cache into rows.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.homeUsesCachedPresentationAndStableTaskIDs` asserts that Home keeps the row-number cache and does not restore the former render-path collection pass. The iOS UI performance suite seeds 360 tasks and 1,200 timeline entries for scrolling checks.
