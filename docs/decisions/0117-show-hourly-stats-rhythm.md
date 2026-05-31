# 0117: Show Hourly Stats Rhythm

## Status

Accepted

## Date

2026-05-31

## Context

Daily and weekday charts show how activity changes across dates, but they do not reveal what time of day the user tends to focus, complete work, or create tasks.

## Decision

Stats includes a 24-hour rhythm chart on iOS and macOS. The chart groups the selected Stats range by clock hour and lets the user switch between focus time, completed work, created tasks, and total timeline activity.

Focus sessions are split across the actual clock hours they occupy. Completed work and timeline activity use routine log timestamps, while created tasks use task creation timestamps. The section follows the same task, query, tag, importance/urgency, and date-range filters as the rest of Stats.

## Consequences

- Users can see which hours of the day carry the most focus and activity.
- Long focus sessions that cross an hour boundary contribute proportionally to each hour.
- Hourly rhythm is a presentation layer over existing task, log, and focus-session data; it does not introduce new persistence.
