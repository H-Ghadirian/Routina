# 0118: Show Focus Chart Details and Grouping

## Status

Accepted

## Date

2026-05-31

## Context

The focus chart shows daily totals, but users also need to inspect the exact focus duration behind a bar and understand which tasks contributed to it. Year-range daily bars can also be too granular when the user wants a weekly or monthly review.

## Decision

Stats focus duration points carry task-level focus contributions in addition to total seconds. The Focus time chart lets the user switch between day, week, and month buckets, and selection or hover shows the exact focused duration plus the top focused tasks for the selected bucket.

Completed focus sessions remain bucketed by their completion day before optional week or month grouping. Unassigned focus sessions are shown as unassigned focus in the breakdown.

## Consequences

- Users can inspect what each focus bar represents without leaving Stats.
- Weekly and monthly focus views are derived from the same selected range and filters as the daily chart.
- The feature reuses existing focus-session persistence and does not add new stored data.
