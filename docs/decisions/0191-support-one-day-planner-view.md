# 0191 Support One-Day Planner View

Status: Accepted

Date: 2026-06-09

Refines: [0005 Show Timeline Activity in the Day Planner](0005-show-timeline-activity-in-day-planner.md), [0006 Make Planner Timeline Activity Configurable](0006-make-planner-timeline-activity-configurable.md)

## Context

The planner week view is useful for arranging work across nearby days, but it can create extra visual noise when the user wants to focus only on today or another selected day. Users need a lightweight way to narrow the planner to a single day without changing the underlying planner data model.

## Decision

The planner supports a `Day / Week` view mode. Week remains the default and continues to show the existing seven-day planner surface. Day mode shows only the selected day while preserving the same timed grid, all-day lane, timeline activity, events, sleep, away, focus, drag/drop, and editing behavior.

The Today button still returns to today. The previous/next controls follow the active mode: one day at a time in Day mode and seven days at a time in Week mode.

Day mode is presentation state. Planner blocks, timeline suggestions, all-day task data, event records, and protected-session records keep their existing storage semantics.

## Consequences

Users can reduce the planner to a focused one-day view without hiding or rewriting adjacent days' data.

Shared planner logic should consume the visible date range instead of assuming the calendar always renders a full week.
