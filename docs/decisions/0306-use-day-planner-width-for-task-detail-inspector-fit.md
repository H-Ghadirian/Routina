# 0306: Use Day Planner Width for Task Detail Inspector Fit

## Status

Accepted

## Date

2026-06-28

## Refines

- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)
- [0299: Constrain Mac Home Window Size for Planner Inspector](0299-constrain-mac-home-window-size.md)
- [0303: Align Mac Planner Range Picker with Adaptive Days](0303-align-mac-planner-range-picker-with-adaptive-days.md)

## Context

The Mac Home minimum window size can fit the task list, a right-side task-detail companion pane, and a Planner calendar if the Planner adapts down to Day. The previous companion-pane fit check required the wider comfortable Planner content width before showing task details, so the pane could stay hidden even though the adaptive Planner could make room by rendering one day.

## Decision

When deciding whether the right-side task-detail companion pane can open beside Planner, Mac Home uses the fixed task-detail pane width plus a Day-capable Planner content width. Once the pane is visible, the Planner calendar receives the remaining width and its existing adaptive range logic can reduce Week or 3 Days down to Day.

In the companion-pane layout, the Day calendar can use a narrower minimum grid width than the regular standalone Planner. This lets the time column and single day column fit inside the compact Planner surface after its normal content padding.

The wider comfortable Planner content width remains useful for normal layouts, but it is not the breakpoint for allowing the task-detail inspector. Planner storage and the user's preferred range are unchanged.

## Consequences

- Selecting or opening a task while Planner is active can show the right-side task-detail pane at the current minimum Home window size.
- Tight Planner-plus-inspector layouts preserve context by showing a compact Day calendar instead of hiding task details.
- The companion pane still stays hidden only when the detail area cannot fit the fixed pane plus a Day-capable Planner surface.
