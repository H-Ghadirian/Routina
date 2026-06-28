# 0308: Add Planner Calendar and List Display Modes

## Status

Superseded

## Date

2026-06-28

## Superseded By

- [0309: Show Full Timeline in Planner List Mode](../0309-show-full-timeline-in-planner-list-mode.md)

## Refines

- [0280: Show Timeline Newest First](../0280-show-timeline-newest-first.md)
- [0292: Unify Planner Header Date Control](../0292-unify-planner-header-date-control.md)
- [0303: Align Mac Planner Range Picker with Adaptive Days](../0303-align-mac-planner-range-picker-with-adaptive-days.md)

## Context

Planner is the primary Mac Home landing surface, but it only rendered the calendar grid in its main area. Users sometimes need the same date-range context as the Planner while reviewing historical activity in a linear timeline shape instead of a time-grid shape.

The existing Timeline workspace remains useful for full timeline navigation and filtering, but switching workspaces just to review activity for the current Planner range breaks the Planner context.

## Decision

Mac Planner offers a `Calendar` / `List` display-mode segmented control in the Planner header.

`Calendar` mode preserves the existing Planner calendar grid, calendar filters, date picker sidebar, slot actions, all-day lane, and range controls.

`List` mode replaces the main Planner area with a timeline-style list for the Planner's current visible date range. The list keeps Timeline ordering: newest day first, newest entry first within each day, with date headers above rows. Previous/next and Day/3 Days/Week continue to control the visible range. Calendar-only filters and the date-picker sidebar stay scoped to `Calendar` mode.

Opening task-backed rows from Planner List keeps the user in Planner and opens the existing right-side task-detail companion pane. Rows that need dedicated non-task detail routes continue to use their established Timeline/detail destinations.

Planner display mode is view state; it does not change stored Planner blocks, timeline records, or task data.

## Consequences

- Users can review recent timeline activity for the current Planner range without leaving Planner.
- Calendar editing interactions stay isolated to Calendar mode, reducing accidental slot/filter/sidebar interactions while in List mode.
- Existing Timeline ordering and detail routing remain the source of truth for the list presentation.
