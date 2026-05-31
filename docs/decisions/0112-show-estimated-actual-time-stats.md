# 0112: Show Estimated Actual Time Stats

## Status

Accepted

## Date

2026-05-31

## Context

Tasks can store planned duration estimates, and completed activity can store actual time spent. Stats already shows completion and focus activity, but it does not reveal whether planned task durations match logged time.

## Decision

Stats includes an Estimated vs Actual Time chart that aggregates completed work by day for the selected range. A completion contributes only when its task has an estimate and the completion has logged actual time, using the completion log duration first and the one-off task actual duration as a fallback.

The chart remains factual and uses stored task/log durations; it does not infer actual time from missing logs or focus sessions.

## Consequences

- Users can compare planned and spent time alongside other Stats charts.
- Routine completions without logged actual time are omitted rather than treated as zero actual time.
- One-off tasks can still contribute through their task-level actual duration, matching how time spent is stored for todos.
