# 0342: Use Single-Date Jump in Planner Timeline

## Status

Accepted

## Date

2026-07-05

## Refines

- [0309: Show Full Timeline in Planner List Mode](0309-show-full-timeline-in-planner-list-mode.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

Planner Timeline is intentionally not scoped by the Planner calendar range, but the shared `Go to date` sidebar still inherited Calendar range wording. In Timeline mode that made the control look like a range picker even though selecting a date should be a jump target for the full Timeline list.

## Decision

In Planner Timeline mode, `Go to date` presents and summarizes one selected date, not the current Calendar visible range. Selecting a date updates the Planner selected date and asks the Timeline list to scroll to the matching visible date section when one exists. If the selected date has no visible Timeline section under the current search and filters, the Timeline list stays where it is.

The Timeline list remains full, newest-first, and unscoped by Planner date or visible Calendar range. Calendar mode keeps the range-aware date/range button and date picker behavior.

## Consequences

- Timeline date access now behaves like a single-day jump instead of implying range filtering.
- Users can jump to an existing day in the full Timeline without losing the current Timeline filters or search.
- Returning to Calendar still lands on the selected Planner date.
