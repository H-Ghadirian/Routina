# 0006: Make Planner Timeline Activity Configurable

## Status

Accepted

## Date

2026-05-09

## Context

[0005](0005-show-timeline-activity-in-day-planner.md) made past timeline activity visible in the day planner so users can review tasks that happened on a date but were not placed in the plan. That is useful for review, but some users want the planner calendar to stay focused only on planned blocks unless they opt into the timeline activity overlay.

## Decision

The day planner keeps timeline activity visible by default, but users can turn automatic placement off from Settings > Calendar. When enabled, the planner renders unplanned completed, missed, and canceled timeline activity directly in the calendar as automatic blocks.

Automatic timeline blocks are not persisted planner blocks. They are derived from timeline logs or legacy task completion/cancel timestamps, hidden when the same task already has a manual planner block for that date, and styled differently from user-placed blocks with dashed borders and a tinted side rail. Moving one updates the underlying timeline timestamp so the change is reflected in the task's detail and history.

When automatic placement is turned off, the planner calendar falls back to day-column timeline badges. Selecting a badge focuses the sidebar on that date's unplanned timeline activity list, preserving the earlier review workflow without placing those activities into the grid.

The setting keeps using the existing underlying user-default key that previously controlled unplanned timeline badges, so prior user choices are preserved while the UI copy now describes the broader planner behavior.

## Consequences

- Settings > Calendar owns planner timeline visibility because it changes calendar/planner behavior rather than visual appearance.
- Turning the setting off hides the automatic timeline block layer from the planner calendar, but still exposes unplanned timeline activity through badges and the sidebar activity list.
- Turning the setting on clears any active legacy timeline-activity focus because the activities are visible in the grid instead.
- The planner does not show day-column badge counters while the automatic block layer is enabled.
- Automatic timeline blocks can be moved, but they remain distinct from manual planner blocks and are not resized or deleted through the planner block controls.
- Timeline activity remains part of Routina's historical data model; this setting only affects whether the planner automatically surfaces it.
