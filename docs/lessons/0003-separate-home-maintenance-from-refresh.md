# 0003 — Separate Home maintenance from refresh

Date: 2026-07-23

## Symptom

The production macOS app could consume a substantial fraction of a CPU core for seconds while Home or Planner appeared idle. Older Macs felt slow and heavy when the app launched or refreshed.

## Root Cause

Every Home task reload ran whole-history repair work before fetching presentation data: duplicate-name reconciliation, same-day log deduplication, missing-log backfill, and orphan cleanup. SwiftUI view reappearances could also request another load after a valid task snapshot already existed. With a large history, each refresh repeatedly decoded and traversed all task and log models.

## Fix

Home now performs repair and migration maintenance only while establishing its initial task snapshot. Ordinary notifications, post-mutation reloads, and reappearances use the lightweight fetch path. The Home refresh observer no longer schedules an initial-load action when a valid snapshot is already present.

## Prevention Rule

Do not put migrations, deduplication, repair, or orphan cleanup in a frequently used presentation refresh path. Make maintenance an explicit startup or migration operation, and keep ordinary refreshes limited to loading current presentation data.

## Regression Safeguard

`PerformanceRegressionTests.testMacHomeRunsWholeHistoryMaintenanceOnlyForInitialLoad` verifies the initial-load boundary, the lightweight default reload path, and the already-loaded appearance guard.
