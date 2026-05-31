# 0108: Show Stats Outcome Mix

## Status

Accepted

## Date

2026-05-31

## Context

Stats already counted done, missed, and canceled timeline activity together for the daily activity chart. That total is useful for volume, but it hides whether a high-activity day was mostly completed work, missed assumptions, or cancellations.

## Decision

Stats shows the timeline activity chart as a stacked outcome mix across done, missed, and canceled activity. The chart keeps the existing date range, task type, importance/urgency, query, and tag filters, and it derives outcome buckets from the same filtered `RoutineLog` rows as the existing totals.

Canceled activity remains neutral, missed activity stays visually distinct from cancellation, and done activity uses a positive accent.

## Consequences

- Users can see both activity volume and outcome quality in one chart.
- Existing total activity summaries and peak-day calculations remain based on the sum of all three outcome kinds.
- iPhone and Mac Stats continue to share one derived data path for the activity chart.
