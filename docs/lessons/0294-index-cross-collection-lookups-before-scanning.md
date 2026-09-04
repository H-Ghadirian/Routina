# 0294 — Index cross-collection lookups before scanning

Date: 2026-09-03

## Symptom

The production-volume Timeline grouping regression took about 140 seconds in a
Debug hosted-test run for 1,800 tasks and 16,000 logs.

## Root Cause

Synthetic `lastDone` fallback generation scanned every resolved log for every
task. SwiftData model-property access amplified the quadratic task-by-log work.

## Fix

Timeline builds a one-pass index of completion calendar days by task ID, then
performs constant-time membership checks while adding missing synthetic logs.
Inserted fallbacks update the same index so duplicate task IDs preserve the
previous semantics.

## Prevention Rule

Before correlating two history-sized collections, build a lookup keyed by the
fields used for membership. Do not place a complete collection scan inside the
other collection's loop.

## Regression Safeguard

`TimelineLogicTests.lastDoneFallbackIndexPreservesCalendarDaySemantics` covers
existing-log and fallback behavior. The 1,800-task/16,000-log Timeline
performance test now completes within the roughly 11-second full performance
test operation instead of dominating it for minutes.

Related decision: [0418 — Keep whole-history work out of scrolling render paths](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md).
