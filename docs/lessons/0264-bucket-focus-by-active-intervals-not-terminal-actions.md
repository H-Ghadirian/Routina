# 0264 — Bucket Focus by active intervals, not terminal actions

Date: 2026-08-29

## Symptom

A Focus timer was started and paused yesterday, then finished today. Timeline
showed the work under yesterday, but Stats assigned the complete duration to
today. A continuous session crossing midnight likewise could not give each day
only its actual portion.

## Root Cause

Timeline and Stats independently chose one timestamp to represent a session.
Timeline used the start while Stats used completion, so neither derivation
modeled the active intervals that the duration actually described. Aggregate
paused seconds were enough to preserve a total but not enough to locate paused
gaps on the calendar.

## Fix

A shared Focus interval resolver now reconstructs uninterrupted activity from
persisted Pause and Resume actions, validates it against the session's
authoritative active duration, and splits it at local day boundaries. Timeline,
Focus-duration Stats, and hourly Focus Stats consume those same intervals.
Legacy aggregate-only records preserve their known duration from the recorded
start instead of being assigned to the Finish day.

## Prevention Rule

When time evidence can cross a reporting boundary, bucket intersections of its
actual active intervals. Never attribute an interval's complete duration to a
start, completion, or button-action timestamp as a shortcut.

## Regression Safeguard

The Overnight Focus scenario covers continuous and paused sessions.
`Tests/Shared/RoutineCompletionStatsTests.swift` verifies daily and hourly
allocation, including 23:00-03:00 as one hour plus three hours and a paused
session finished the next day as zero Focus on the finish day.
`Tests/Shared/TimelineLogicTests.swift` verifies matching per-day Timeline rows.
