# 0002 — Keep Timeline change detection out of the render path

Date: 2026-07-23

## Symptom

The macOS Timeline became increasingly slow and heavy as the user's history grew, especially while scrolling on older Macs.

## Root Cause

The Timeline view observed thirteen unbounded SwiftData `@Query` collections. Its SwiftUI body also depended on change-token computed properties that mapped every task, log, attachment, event, note, and session into strings. SwiftUI could reevaluate those properties during layout and scrolling, making render cost proportional to the user's complete history.

## Fix

Timeline now fetches an explicit data snapshot when the surface appears or the app's coalesced routine-update notification fires. It keeps the last snapshot stable during active macOS scrolling and applies a deferred refresh after the scroll quiet window. The full-history render-path change tokens were removed.

## Prevention Rule

Never use unbounded SwiftData `@Query` collections or whole-history change-token construction in Timeline, Planner, Stats, or another scrolling view body. Fetch at explicit invalidation boundaries and render from a stable snapshot.

## Regression Safeguard

`PerformanceRegressionTests.testMacTimelineDoesNotBindWholeHistoryQueriesIntoRenderPath` verifies that Mac Timeline has no `@Query`, uses explicit snapshot fetching, listens through the app-owned update fan-in, defers refresh during scrolling, and does not recreate the old full-history token.
