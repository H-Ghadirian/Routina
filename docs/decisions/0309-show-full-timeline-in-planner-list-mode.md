# 0309: Show Full Timeline in Planner List Mode

## Status

Accepted

## Date

2026-06-28

## Supersedes

- [0308: Add Planner Calendar and List Display Modes](superseded/0308-add-planner-calendar-list-display-mode.md)

## Refines

- [0280: Show Timeline Newest First](0280-show-timeline-newest-first.md)
- [0292: Unify Planner Header Date Control](0292-unify-planner-header-date-control.md)
- [0303: Align Mac Planner Range Picker with Adaptive Days](0303-align-mac-planner-range-picker-with-adaptive-days.md)

## Refined By

- [0318: Remove Mac Home Timeline Toolbar Segment](0318-remove-mac-home-timeline-toolbar-segment.md)
- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)
- [0325: Rename Planner List Segment to Timeline](0325-rename-planner-list-segment-to-timeline.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

Planner List mode was first introduced as a timeline-style view scoped to the Planner's current visible date range. That made the list depend on Calendar range controls even though the user's intent for List mode is to review the whole timeline in the Planner surface.

When List mode is not range-scoped, leaving Today, previous/next, Day/3 Days/Week, filter, or date controls visible in the header suggests those controls change the main list even though they are Calendar-only concepts.

## Decision

Mac Planner offers a `Calendar` / `List` display-mode segmented control in the Planner header.

`Calendar` mode preserves the editable Planner calendar grid, calendar filters, date picker sidebar, slot actions, all-day lane, and range controls.

`List` mode replaces the main Planner area with all timeline-style entries, not only entries in the selected Planner date, Day, 3 Days, Week, or visible range. The list keeps Timeline ordering: newest day first, newest entry first within each day, with date headers above rows.

In List mode, the header keeps the `Calendar` / `List` switch visible and hides Calendar-only controls, including Today, previous/next, Day/3 Days/Week, the calendar filter button, and the Planner date picker. Those controls remain available in Calendar mode.

Opening task-backed rows from Planner List keeps the user in Planner and opens the existing right-side task-detail companion pane. Rows that need dedicated non-task detail routes continue to use their established Timeline/detail destinations.

Planner display mode is view state; it does not change stored Planner blocks, timeline records, task data, or Timeline workspace filters.

## Consequences

- Users can review the full timeline from Planner without leaving Planner or changing a Calendar range.
- Calendar-only controls no longer imply they scope the List mode main area.
- Existing Timeline ordering and detail routing remain the source of truth for the list presentation.
