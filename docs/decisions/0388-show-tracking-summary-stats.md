# 0388 Show Tracking Summary Stats

Status: Accepted

Date: 2026-07-13

Refines: [0236 Hide Empty Stats Reports](0236-hide-empty-stats-reports.md), [0380 Add Record Task Type](0380-add-record-task-type.md), [0383 Use Tracking as Record Label](0383-use-tracking-as-record-label.md)

## Context

Tracking entries are meant for analyzing what happened and how time was spent. They already participate in Stats filtering, but the dashboard did not expose Tracking-specific summary cards in the default Stats surface.

Users need lightweight Tracking stats without turning Tracking into a planning bucket or mixing its time-spend meaning into routine/todo counts.

## Decision

Stats summary cards include Tracking-specific reports:

- `Tracking` counts matching tracking entries and shows active versus archived tracking entries.
- `Tracking time` sums selected-range actual time from completed tracking logs, plus entry-level actual time for tracking entries created in the selected range when those entries do not already have a completed tracking log in range.

These reports follow the existing empty-report rule: `Tracking` appears only when matching tracking entries exist, and `Tracking time` appears only when selected-range tracked time is nonzero. The Stats task-type filter is visible when tracking entries exist, even if no todos exist.

## Consequences

Stats can summarize Tracking usage in the All dashboard and in Tracking-filtered views.

Tracking time remains range-scoped, while Tracking entry counts remain inventory-style like routine and open-todo counts.

Future Tracking stats should preserve the user-facing `Tracking` label and keep log-based time distinct from synthetic or assumed routine activity unless a later decision opts in explicitly.
