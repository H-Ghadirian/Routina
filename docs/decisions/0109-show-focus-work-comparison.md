# 0109: Show Focus Work Comparison

## Status

Accepted

## Date

2026-05-31

## Context

Focus duration and completed work are useful separately, but users also need to see whether focused days line up with finished tasks. A single count or time total does not show days where focus produced completions, focus happened without completions, or completions happened without a recorded focus session.

## Decision

Stats includes a focus-versus-completed-work chart for week, month, and year ranges. Each dot represents a day, plotting completed tasks against focus minutes for the same filtered Stats range.

The chart uses the existing filtered daily focus series and the done count from the daily outcome mix. Days with focus and done work, focus only, and done only are visually distinct.

## Consequences

- Users can compare focus effort with finished work without changing filters or leaving Stats.
- The comparison uses the same date range, task type, query, importance/urgency, and tag filters as the other Stats charts.
- Today is excluded for now because the chart is designed to compare multiple days.
