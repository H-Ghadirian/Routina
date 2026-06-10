# 0202 Nest Daily Routines Under Mac Plan Today

Status: Accepted

Date: 2026-06-10

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md)

## Context

The Mac Home sidebar is a compact working list. Showing `Plan to do today` and `Daily Routines` as sibling sections made two forms of "today work" compete at the same hierarchy level.

Daily routines are still not individually planned tasks: they do not expose planning controls and stale imported `plannedDate` values remain ignored. But in the Mac sidebar, they should read as part of the user's plan for the current day.

## Decision

The Mac Home sidebar presents daily routines inside the collapsible `Plan to do today` section. Planned non-daily tasks appear first, followed by an inner `Daily Routines` group.

The inner `Daily Routines` group is independently collapsible and defaults to collapsed on Mac, so the parent today section can stay focused on explicitly planned work while daily routines remain one disclosure away.

Each inner group keeps its own manual ordering bucket: planned tasks use `plannedToday`, and daily routines use `daily`.

iOS keeps the existing top-level `Daily Routines` section because its Home list has different navigation density and this change is scoped to the Mac sidebar.

## Consequences

Mac users get one primary today section instead of two sibling today sections.

Manual ordering remains compatible with existing stored section keys, so moving daily routines does not rewrite planned-task ordering and vice versa.

The nested daily collapse preference is Mac-specific; iOS keeps its existing top-level daily routine section state.
