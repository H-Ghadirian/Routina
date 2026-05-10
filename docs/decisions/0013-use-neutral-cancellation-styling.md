# 0013: Use Neutral Cancellation Styling

## Status

Accepted

## Date

2026-05-10

## Context

Task detail surfaces used orange for both due and canceled states. In the calendar, a canceled exact-time occurrence could also inherit missed styling when the canceled log resolved a previously missed assumption. This made canceled, due, and missed outcomes hard to distinguish at a glance.

## Decision

Routina uses neutral gray styling for canceled outcomes in task detail surfaces. Due and soon-due states keep orange urgency styling, missed occurrences keep yellow styling, and overdue states keep red styling.

When an exact-time missed occurrence is resolved as canceled, that canceled log acknowledges the missed assumption. Calendar rendering also gives canceled dates precedence over missed dates if both are present for the same occurrence day.

## Consequences

- Calendar legends and day circles show canceled separately from due and missed.
- Routine log status text and task-detail canceled badges use the same neutral cancellation styling.
- Canceled exact-time occurrences no longer reappear as unresolved missed assumptions.
