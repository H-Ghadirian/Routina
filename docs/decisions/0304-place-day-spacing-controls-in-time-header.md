# 0304: Place Day Spacing Controls in the Time Header

## Status

Accepted

## Date

2026-06-28

## Refines

- [0282: Expand Day Planner Hour Spacing](0282-expand-day-planner-hour-spacing.md)
- [0292: Unify Planner Header Date Control](0292-unify-planner-header-date-control.md)
- [0303: Align Mac Planner Range Picker with Adaptive Days](0303-align-mac-planner-range-picker-with-adaptive-days.md)

## Context

Day mode hour spacing is a presentation-only planner control, but keeping the zoom buttons in the top header competed with range navigation and the canonical date/range control. The calendar already has a stable `Time` header cell that visually owns the hour axis the controls affect.

## Decision

Planner Day mode places the hour spacing controls inside the calendar `Time` header cell as a compact vertical button stack. The controls remain available only when the effective Planner range is `Day`.

The top header keeps period navigation and range selection separate from the calendar-axis zoom controls: Today, previous/next, and Day/3 Days/Week stay in the navigation/view cluster; the canonical date/range control remains in the utility cluster.

## Consequences

- The Day header has more horizontal room for the range picker and date control.
- The spacing controls sit next to the hour labels they affect.
- `3 Days` and `Week` continue to hide the spacing controls and use the standard compact hour height.
