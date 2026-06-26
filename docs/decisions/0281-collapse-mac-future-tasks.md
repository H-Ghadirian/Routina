# 0281 Collapse Mac Future Tasks

Status: Accepted

Date: 2026-06-26

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0202 Nest Daily Routines Under Mac Plan Today](0202-nest-daily-routines-under-mac-plan-today.md), [0247 Make Mac Daily Routine Grouping Optional](0247-make-mac-daily-routine-grouping-optional.md), [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md)

Refined by: [0283 Preserve Mac Future Inner Sections](0283-preserve-mac-future-inner-sections.md)

## Context

The Mac Home sidebar is meant to keep today's working plan prominent. After `Plan to do today`, normal status, deadline, tag, or ungrouped sections can still take a lot of visual space and compete with today's tasks.

Those non-today sections still need to keep their existing internal organization and manual ordering. Flattening them into one undifferentiated list would make tag/status grouping and drag ordering less predictable.

## Decision

The Mac Home sidebar groups normal active tasks that are not in `Plan to do today` into one top-level collapsible `Future` section.

`Future` defaults collapsed. Inside `Future`, the existing regular grouping mode is preserved as non-collapsible inner groups: status and deadline sections keep their titles, tag grouping keeps tag titles, and ungrouped mode shows the rows directly without a redundant `Tasks` title.

Pinned tasks and archived tasks keep their existing top-level sections. Daily routines continue to live inside `Plan to do today`, using the existing `Separate daily routines in task list` setting for the optional nested `Daily Routines` group. iOS keeps its existing top-level task sections.

## Consequences

Mac Home opens with today's work more visually dominant while future work remains accessible one disclosure away.

The shared presentation model still claims each task ID once and preserves durable move-context keys for planned, daily, regular, tag, ungrouped, pinned, and archived ordering.

The `Future` expanded/collapsed state is a local sidebar presentation preference, matching the existing section-collapse preferences.
