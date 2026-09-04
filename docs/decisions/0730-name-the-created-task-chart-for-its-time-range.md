# 0730 — Name the Created-Task Chart for Its Time Range

## Status

Accepted

## Date

2026-09-04

## Refines

- [0415 — Support Custom Stats Date Ranges](0415-support-custom-stats-date-ranges.md)
- [0668 — Separate General Stats and Standardize Task-Type Language](0668-separate-general-stats-and-standardize-task-type-language.md)

## Context

The created-task chart kept the heading `Tasks created per day` while the Stats
Time Range changed among Day, Week, Month, and Year. The subtitle and chart data
reflected the selected period, but the fixed heading made a Year report look as
though its scope were still Day.

## Decision

For the standard Stats presets, name the created-task chart for the selected
range: `Tasks created per day`, `Tasks created per week`, `Tasks created per
month`, or `Tasks created per year`. Keep arbitrary Custom ranges labeled
`Tasks created per day` because their chart axis continues to present individual
dates rather than a named preset period.

This is a presentation change only. Selected boundaries, daily chart points,
totals, averages, highlights, task-type filtering, and the rule that hides the
chart for a one-day range remain unchanged.

## Consequences

- The chart heading immediately confirms which standard Time Range is active.
- Moving among Week, Month, and Year no longer leaves stale Day wording.
- Custom ranges keep a stable label without inventing a calendar unit for an
  arbitrary interval.
