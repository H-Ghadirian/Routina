# 0301: Adapt Mac Planner Week Visible Days

## Status

Superseded

## Date

2026-06-28

## Superseded by

- [0303: Align Mac Planner Range Picker with Adaptive Days](../0303-align-mac-planner-range-picker-with-adaptive-days.md)

## Refines

- [0191: Support One-Day Planner View](../0191-support-one-day-planner-view.md)
- [0299: Constrain Mac Home Window Size for Planner Inspector](../0299-constrain-mac-home-window-size.md)

## Context

Planner Week mode previously rendered seven days whenever Week was selected. That works on wide windows, but becomes cramped when Mac Home also shows the task sidebar and task-detail companion pane. The app should preserve the Week mental model while rendering a number of days that the available calendar width can actually support.

## Decision

On macOS, Week mode adapts its visible day count from the Planner calendar column width:

- wide calendars show seven days,
- medium calendars show three days,
- narrow calendars show one day.

Day mode remains an explicit one-day mode with its existing day-specific hour spacing controls. Adaptive one-day Week mode keeps Week selected and uses the standard Week hour spacing.

The visible range title, Today visibility, loaded planner data, and previous/next navigation follow the effective visible day count. Previous/next moves by seven, three, or one day in Week mode based on the current adaptive range. Planner storage remains unchanged.

## Consequences

- Mac Home can keep sidebar, Planner, and task details visible without squeezing seven unreadable day columns.
- Users still choose between `Day` and `Week`; Week now means a width-adaptive multi-day planning range rather than always seven columns.
- Planner state and rendering code must consume the effective visible dates instead of assuming Week always contains seven days.
