# 0252: Stabilize Home Task List Presentation Identity

## Status

Accepted

## Date

2026-06-19

## Refines

- [0200: Support Task Planned Dates](0200-support-task-planned-dates.md)
- [0202: Nest Daily Routines Under Mac Plan Today](0202-nest-daily-routines-under-mac-plan-today.md)
- [0240: Keep Checklist Runout Item Actions Item-Scoped](0240-keep-checklist-runout-item-actions-item-scoped.md)
- [0247: Make Mac Daily Routine Grouping Optional](0247-make-mac-daily-routine-grouping-optional.md)

## Context

Task rows can move between pinned, planned, daily, regular, away, archived, and status sections as state changes. When each section independently filters tasks or when SwiftUI identity is based on visible titles, refreshes can briefly make one task look like two rows or make a section look replaced instead of updated.

That replacement shows up as blinking, jumping rows, collapsed-section confusion, and duplicate task rows. Checklist runout routines exposed the issue, but the underlying risk exists anywhere Home task lists are derived from overlapping source arrays or changing status flags.

## Decision

Home task list presentation owns the stable identity contract:

- A visible task ID is claimed once per presentation in display-priority order.
- Status section membership is assigned by one classifier, not by multiple independent bucket filters.
- Presentation section identity uses stable keys, not human-readable titles.
- Inner task-group identity prefers move-context keys over visible titles.
- Views should render task rows from the shared presentation model instead of rebuilding their own section membership.

## Consequences

- One task cannot render as two rows because it appears in overlapping active, away, archived, planned, daily, or status inputs.
- Renaming or localizing section titles does not reset SwiftUI section identity.
- Daily routine grouping can show or hide the `Daily Routines` label without replacing the underlying group identity.
- Future task-list changes should add new classifier keys or presentation groups instead of adding platform-specific filtering passes.
