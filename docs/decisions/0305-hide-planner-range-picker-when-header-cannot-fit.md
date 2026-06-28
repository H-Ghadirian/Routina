# 0305: Hide Planner Range Picker When Header Cannot Fit

## Status

Accepted

## Date

2026-06-28

## Refines

- [0292: Unify Planner Header Date Control](0292-unify-planner-header-date-control.md)
- [0303: Align Mac Planner Range Picker with Adaptive Days](0303-align-mac-planner-range-picker-with-adaptive-days.md)
- [0304: Place Day Spacing Controls in the Time Header](0304-place-day-spacing-controls-in-time-header.md)

## Context

The Mac Planner header needs to keep previous/next navigation, calendar filters, and the canonical date/range control available on one row. The Planner calendar can also adapt from Week down to 3 Days or Day based on available calendar column width, but that adaptation is not the same as the header running out of horizontal room.

Hiding the `Day` / `3 Days` / `Week` segmented picker whenever the visible range adapts below Week removes the picker in layouts where the header still has enough space, especially 3-day layouts without a task-detail companion pane.

## Decision

The Mac header measures whether the full one-row control set can fit: previous/next navigation, the `Day` / `3 Days` / `Week` segmented picker, filter, and date/range controls. If that measured row fits, the segmented picker stays visible, even when the effective Planner range is 3 Days or Day.

Only when the full one-row control set cannot fit does the header hide the segmented picker. The header still keeps previous/next navigation, filter, and date/range controls on the same row. User range preference and planner storage remain unchanged while the picker is hidden.

## Consequences

- 3-day layouts can still show the range picker when the header has enough horizontal space.
- Tight layouts prioritize date navigation and filters over view-range switching.
- Width adaptation remains presentation-only and does not change stored Planner data.
