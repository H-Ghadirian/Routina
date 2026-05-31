# 0119: Show Cumulative Focus Chart

## Status

Accepted

## Date

2026-05-31

## Context

Daily, weekly, and monthly focus bars show how focus is distributed across the selected Stats range, but they do not show the running total of focus time as the range progresses.

## Decision

The Focus time section includes a cumulative daily focus chart derived from the same filtered daily focus duration points. Each point carries that day's focus seconds and the running total through that day.

The cumulative chart uses the selected Stats date range and filters, and it remains a presentation layer over existing focus-session data.

## Consequences

- Users can see whether focus time is steadily accumulating or concentrated in a few bursts.
- The cumulative chart stays consistent with the focus bar chart because both are derived from the same daily focus points.
- No new persistence is introduced.
