# 0089 — Refresh time-derived Home displays before filtering

Date: 2026-08-07

## Symptom

`Hide assumed-done tasks` could leave a two-week `After done` task visible in Home after it became assumed done while Home was already open.

## Root Cause

Home filters operate on cached display rows. Changing the filter did not rebuild those rows, so their assumed-done flag could describe an earlier point in time.

## Fix

On iOS and macOS, changing `Hide assumed-done tasks` now refreshes the loaded Home display snapshot before the Task List applies the filter.

## Prevention Rule

Before filtering on time-derived task state, refresh the cached display projection at the explicit user action that relies on that state.

## Regression Safeguard

The iOS and macOS `HomeFeatureTests.hideAssumedDoneTasksRefreshesAnAfterCompletionAssumption` tests start from an intentionally stale Home display, enable the filter, and verify the two-week `After done` task becomes assumed done in the refreshed projection. The repeating-task scenario also records the user-visible expectation.
