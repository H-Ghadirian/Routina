# 0151 — Move large Search presentations off the main actor

Date: 2026-08-12

## Symptom

With 12,000 seeded tasks, opening the iOS Search tab and rapidly typing a long
query with no result could visibly delay keyboard input and result updates.

## Root Cause

The input debounce limited how often the query was applied, but the eventual
full-catalog filtering, sorting, sectioning, and repeated localized field
matching still ran synchronously on the main actor.

## Fix

Searchable Home display snapshots now cache a normalized multi-field search
index. Non-actionable iOS task-list presentations build from immutable value
snapshots in a cancellable detached task, and only the latest completed build
is applied on the main actor. Result replacement uses a short opacity
transition.

## Prevention Rule

Debouncing does not make unbounded work frame-safe. Any task-list presentation
that can scan or sort the full catalog must use cached value data, build away
from the main actor when its inputs are actor-independent, and reject stale or
cancelled results.

## Regression Safeguard

`RoutinaUIPerformanceTests.testLargeSeededRapidNoMatchSearchPerformance` seeds
12,000 tasks and exercises Search activation, keyboard focus, rapid long-query
typing, and the no-match result. Shared filtering tests protect the complete
search vocabulary, while `IOSScrollingPerformanceRegressionTests` protects the
cancellable detached-presentation boundary. Decision 0557 records the durable
architecture.
