# 0189 — Canonicalize focus sessions before deriving Stats

Date: 2026-08-16

## Symptom

Stats reported `36h 6m` of focus for one day while Planner Calendar showed only
about six hours of focus segments for that date.

## Root Cause

Planner had learned to collapse duplicate semantic placements, but Stats still
summed every persisted focus-session row by storage identity. Synchronized
copies with different IDs therefore multiplied the duration of the same logical
sessions.

## Fix

Stats now canonicalizes task, tag, unassigned, and board focus sessions by their
owner and exact start time before each applicable focus derivation, including
focus totals, hourly activity, goal focus, Focus 2048, and task-focus
achievements. Conflicting copies prefer the latest accepted state without
deleting persisted data.

## Prevention Rule

When synchronized records can receive different storage IDs for one logical
activity, every aggregate evidence path must consume the same semantic
canonicalization before counting duration or progress.

## Regression Safeguard

`RoutineCompletionStatsTests.focusDurationPoints_countSemanticSyncCopiesOnce`
recreates six copies of three second-precision focus sessions whose naive sum is
`36h 6m`, then verifies both daily Focus Stats and hourly rhythm report the
single logical `6h 1m` total with three contributing sessions.

Related decision: [0598](../decisions/0598-count-semantic-focus-session-copies-once-in-stats.md).
Related lesson: [0188](0188-deduplicate-planner-placements-by-meaning.md).
