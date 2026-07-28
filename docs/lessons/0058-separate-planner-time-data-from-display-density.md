# 0058 — Separate Planner time data from display density

Date: 2026-07-28

## Symptom

A task estimated at five minutes appeared as a 15-minute synthetic
`Assumed done` interval. Sequential short Schedule cards could also overlap
because each card had a minimum visual height while the hour grid remained
uniform.

## Root Cause

The 15-minute manual slot convention was reused as a model-construction and
automatic-activity-placement minimum. Separately, minimum card height was
applied after uniform time-to-pixel conversion, so visual usability and
semantic duration competed with each other.

## Fix

Synthetic activity and its conflict-avoiding placement now accept the
one-minute storage minimum and preserve the task's exact estimate. Calendar
`Schedule` uses a cached piecewise time axis that expands only when a short
card would intrude into the next non-overlapping visible interval, and every
drawing and interaction layer consumes that same axis.

## Prevention Rule

Never change stored or derived duration data to satisfy a visual minimum.
Treat slot snapping as an input convention, semantic duration as domain data,
and display density as a presentation transform. Route all Schedule geometry
and inverse pointer mapping through the shared time axis.

## Regression Safeguard

`DayPlanPlannerStateTests` verifies that twelve sequential five-minute blocks
receive independent 18-point visual slots while retaining five-minute
durations, that adaptive coordinates round-trip to minutes, and that
assumed-done summary activity preserves a five-minute estimate.
`PerformanceRegressionTests` guards the visible-snapshot cache boundary and
forbids persistence work in the adaptive-axis render path. The
`Dense Planner Hours Preserve Exact Short Durations` scenario records the
cross-layer expectation.
