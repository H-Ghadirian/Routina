# 0292 — Cache toolbar counts with the display snapshot

Date: 2026-09-03

## Symptom

Reevaluating the Mac Home toolbar scanned the complete task collection twice to
count repeating and active one-time tasks, including during scrolling-driven
SwiftUI updates.

## Root Cause

The counts were convenient computed expressions in `body` even though the same
membership had already been derived for Home's display snapshot.

## Fix

Home state stores both toolbar counts and refreshes them alongside the routine
and board display snapshots. The toolbar reads only those scalar values. Focus
availability likewise uses display membership and materializes model candidates
only when the picker opens.

## Prevention Rule

If UI chrome summarizes a potentially unbounded collection, derive the summary
at the collection's snapshot boundary and render the cached scalar.

## Regression Safeguard

`PerformanceRegressionTests.testHomeToolbarRenderingDoesNotScanAllTasks`
requires the toolbar to read cached counts and guards their refresh ownership.

Related decision: [0418 — Keep whole-history work out of scrolling render paths](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md).
