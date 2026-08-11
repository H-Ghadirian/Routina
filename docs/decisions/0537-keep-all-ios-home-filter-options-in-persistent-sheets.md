# 0537: Keep All iOS Home Filter Options in Persistent Sheets

## Status

Accepted

## Date

2026-08-11

## Refines

- [0535: Keep iOS Home Filter Details in Dedicated Sheets](0535-keep-ios-home-filter-details-in-dedicated-sheets.md)
- [0534: Present iOS Priority Controls in Dedicated Sheets](0534-present-ios-priority-controls-in-dedicated-sheets.md)
- [0533: Keep Active iOS Filter Tag Rules Visible](0533-keep-active-ios-filter-tag-rules-visible.md)

## Context

The Home Filters sheet still expanded several controls inline after the detailed
Group, Sort, Priority, Tags, and Flags controls had moved into their own
sheets. Those controls made the primary sheet long and costly to scan. A
person also needs to compare or change more than one choice without being sent
back to the main filter sheet each time.

## Decision

Every iOS Home filtering control is represented by a compact entry showing its
current selection. Tapping an entry opens a dedicated sheet for that control;
this includes the optional advanced Query and Goal controls when their feature
gates are enabled.

Changing a picker, segmented control, chip, or toggle updates the binding but
does not dismiss the detail sheet. The person closes it explicitly with Done
or the normal sheet dismissal gesture. Clear Filters remains a direct action
on the main sheet because it is an action rather than a filter choice.

## Consequences

- The primary Home Filters sheet remains short and quickly scannable.
- Current values remain visible before entering a control, while multiple
  related changes can be made in one persistent detail sheet.
- The shared detail-sheet container makes explicit dismissal consistent across
  ordinary Home filter controls without changing Tags, Priority, Group, Sort,
  or Flags' specialized picker behavior.
