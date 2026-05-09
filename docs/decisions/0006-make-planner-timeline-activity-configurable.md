# 0006: Make Planner Timeline Activity Configurable

## Status

Accepted

## Date

2026-05-09

## Context

[0005](0005-show-timeline-activity-in-day-planner.md) made past timeline activity visible in the day planner so users can review tasks that happened on a date but were not placed in the plan. That is useful for review, but some users want the planner calendar to stay focused only on planned blocks unless they opt into the timeline activity overlay.

## Decision

The day planner keeps timeline activity visible by default, but users can turn it off from Settings > Calendar. The preference controls the planner calendar's timeline activity badges and focused timeline task list.

The setting keeps using the existing underlying user-default key that previously controlled unplanned timeline badges, so prior user choices are preserved while the UI copy now describes the broader planner behavior.

## Consequences

- Settings > Calendar owns planner timeline visibility because it changes calendar/planner behavior rather than visual appearance.
- Turning the setting off hides timeline activity affordances from the planner calendar and clears any active timeline-activity focus.
- Timeline activity remains part of Routina's historical data model; this setting only affects whether the planner automatically surfaces it.
