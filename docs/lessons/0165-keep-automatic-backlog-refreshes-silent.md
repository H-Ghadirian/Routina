# 0165 — Keep automatic Backlog refreshes silent

Date: 2026-08-15

## Symptom

The Mac Backlog looked as though it was constantly refreshing while its window
was open, even after raw SwiftData save notifications had been coalesced.

## Root Cause

The semantic update debounce introduced in
[Lesson 0148](0148-coalesce-backlog-refreshes.md) still routed automatic
refreshes through the same action as the manual toolbar command. Every
automatic refresh therefore set `isLoading`, temporarily disabling the refresh
button and replacing an empty Backlog with its loading surface.

## Fix

Backlog now sends a distinct automatic-refresh action after the existing
debounce. It fetches and replaces the reducer-owned snapshot without entering
the user-visible loading state. Initial and manual loads retain their existing
loading feedback.

## Prevention Rule

Background invalidation must not reuse presentation state that exists to
acknowledge an explicit user operation. Keep automatic snapshot replacement
silent unless the existing content cannot remain usable while it loads.

## Regression Safeguard

`BacklogFeatureTests` verifies that automatic refresh stays out of the visible
loading state while manual refresh still enters it. The source boundary in
`PerformanceRegressionTests.testBacklogUsesCoalescedSemanticRefreshes` and the
Mac Backlog scenario also require the silent automatic path.
