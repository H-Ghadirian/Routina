# 0322: Cap Planner Inspector Range to Day Until Roomy

## Status

Accepted

## Date

2026-07-01

## Refines

- [0306: Use Day Planner Width for Task Detail Inspector Fit](0306-use-day-planner-width-for-task-detail-inspector-fit.md)
- [0320: Hide Planner Range Picker in Tight Inspector Layouts](0320-hide-planner-range-picker-in-tight-inspector-layouts.md)

## Context

The Planner task-detail companion pane is allowed to open when the detail area can fit the fixed pane plus a Day-capable Planner surface. The previous adaptive range threshold still allowed `3 Days` in some companion-pane widths where the header was already considered tight and the remaining calendar space looked cramped beside the left task list and right task detail pane.

## Decision

When a right-side companion pane is open, Planner caps its adaptive visible range to `Day` until the measured calendar column reaches the same roomy inspector width used for multi-day header controls. Once that width is available, the existing preferred range can adapt back to `3 Days` or `Week` as before.

Planner storage, the user's preferred range, task-detail pane width, and regular non-inspector Planner thresholds are unchanged.

## Consequences

- Tight Planner-plus-task-detail layouts render a single day column instead of staying in a cramped 3-day state.
- Roomy inspector layouts can still show multiple days.
- The header and calendar now use one consistent idea of when companion-pane layout is roomy enough.
