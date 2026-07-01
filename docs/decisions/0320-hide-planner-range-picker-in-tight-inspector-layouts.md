# 0320: Hide Planner Range Picker in Tight Inspector Layouts

## Status

Accepted

## Date

2026-07-01

## Refines

- [0305: Hide Planner Range Picker When Header Cannot Fit](0305-hide-planner-range-picker-when-header-cannot-fit.md)
- [0306: Use Day Planner Width for Task Detail Inspector Fit](0306-use-day-planner-width-for-task-detail-inspector-fit.md)
- [0307: Hide Planner Range Picker in Day Inspector Layout](0307-hide-planner-range-picker-in-day-inspector-layout.md)

## Context

The Planner header can appear beside a right-side companion pane for task details or Home filters. In those layouts, the measured full header row can still be too optimistic: the `Day` / `3 Days` / `Week` segmented picker may technically fit, but it adds enough pressure that the calendar header, filter button, and date control can visually collide with the companion pane.

The range picker is useful in roomy Planner layouts, but it is secondary to previous/next navigation, the Calendar/List switch, filters, and the canonical date/range control.

## Decision

When the Mac Planner is in an external companion-pane layout, the header hides the `Day` / `3 Days` / `Week` segmented picker unless the available header width is roomy enough and the measured full one-row controls also fit.

The existing Day-inspector rule remains: if a companion pane is open and the effective Planner range is Day, the range picker is hidden even if the row would otherwise fit.

Calendar/List, previous/next, Planner filters, and the date/range control stay available on one row. This roomy-width rule only hides the range picker; Calendar/List labels and the full date/range text remain in their regular presentation until a separate narrower compact-controls threshold is crossed. Range preference, adaptive visible range, Planner storage, and task-detail presentation are unchanged.

## Consequences

- Tight Planner-plus-companion layouts no longer let the range picker crowd or overlap the date control or right pane.
- Intermediate-width companion layouts can hide only the secondary range picker without unnecessarily truncating the date/range button or making Calendar/List icon-only.
- Roomy multi-day inspector layouts can still show the range picker when there is enough space.
- The user's selected/preferred range remains intact while the picker is temporarily hidden.
