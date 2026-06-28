# 0307: Hide Planner Range Picker in Day Inspector Layout

## Status

Accepted

## Date

2026-06-28

## Refines

- [0305: Hide Planner Range Picker When Header Cannot Fit](0305-hide-planner-range-picker-when-header-cannot-fit.md)
- [0306: Use Day Planner Width for Task Detail Inspector Fit](0306-use-day-planner-width-for-task-detail-inspector-fit.md)

## Context

The Planner task-detail companion pane can now stay open at the minimum Mac Home width by letting the Planner calendar adapt down to Day. In that layout, the header may technically have enough measured width to keep the `Day` / `3 Days` / `Week` picker, but showing it crowds the previous/next navigation, filter, and canonical date/range control while adding little value because the calendar is already forced to Day.

## Decision

When the right-side task-detail companion pane is open and the effective Planner range is Day, the Mac Planner header hides the `Day` / `3 Days` / `Week` segmented picker even if the full measured header row would otherwise fit.

The header still keeps previous/next navigation, the filter button, and the date/range control on one row. Wider inspector layouts can still show the picker when the effective range is 3 Days or Week and the full header row fits.

## Consequences

- The minimum-width Planner-plus-task-details layout keeps the primary navigation and utility controls visible without crowding.
- The segmented picker remains available in roomy multi-day layouts.
- Planner range preference and stored Planner data remain unchanged while the picker is hidden.
