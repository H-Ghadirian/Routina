# 0612 — Require comfortable width for expanded Planner header

Status: Accepted

Date: 2026-08-18

Refines [0609: Keep Planner range choices actionable in compact headers](0609-keep-planner-range-choices-actionable-in-compact-headers.md). Refined by [0613: Measure loaded Planner header against visible width](0613-measure-loaded-planner-header-against-visible-width.md).

## Context

The Mac Planner's compact-header fallback originally depended on range eligibility and measured control overflow. That still allowed a Week calendar with all expanded segmented controls and a textual date-range button in a visually crowded header: the row technically fit, but the right utility cluster reached the window edge and the header no longer felt usable.

## Decision

The expanded Calendar header now requires a comfortable overall Planner-header width in addition to its measured 120-point spare-width reserve. Below 1520 points of Calendar header width, Planner view, Calendar task view, and Planner range use current-value menus, and `Go to date` becomes icon-only.

This comfortable-width guard applies to the Calendar control set. Timeline mode keeps using the measured fit and reserve behavior because it does not show the Calendar task-view and range controls.

## Consequences

- Dense Week layouts switch to the Task Ladder-style compact choice pattern before the header looks jammed.
- `Go to date` stops carrying a long date range at widths where the row is visually crowded.
- The 96-point day-column readability minimum remains unchanged, so range eligibility and calendar rendering still use the same column capability calculation.
