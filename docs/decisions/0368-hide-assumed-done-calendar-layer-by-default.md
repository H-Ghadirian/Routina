# 0368: Hide Assumed-Done Calendar Layer by Default

Date: 2026-07-11

Status: Accepted

Refines: [0268 Show Assumed-Done Routines in Planner](0268-show-assumed-done-routines-in-planner.md), [0289 Filter Planner Calendar Layers](0289-filter-planner-calendar-layers.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md)

## Context

Assumed-done routine activity is useful when reviewing synthetic daily routine state, but showing it directly in the timed Planner Calendar by default can make the calendar feel noisier than the task list. Home already hides assumed-done rows by default, and Planner should preserve the same quiet calendar default while still letting the day task list summarize the whole day.

## Decision

Planner still derives eligible assumed-done routine days as synthetic automatic activity, but the timed Calendar presentation hides that synthetic layer by default. The Calendar filter surface exposes an `Assumed done` layer toggle, defaulting off. Turning it on shows synthetic assumed-done activity in the timed grid and Needs Time lane wherever the existing timeline-suggestion layer and search/filter state allow it.

The right-side day task list remains a day summary surface. When timeline suggestions are enabled, its `Assumed done` section can show matching synthetic assumed-done activity even while the timed Calendar layer is hidden. Search, task filters, hidden individual activity, and the overall timeline-suggestion layer still apply.

Recorded completed timeline suggestions stay visible by default. Hiding or showing the assumed-done layer is presentation-only: it does not create completion logs, confirm routine days, delete hidden-activity preferences, or mutate Planner blocks.

## Consequences

- Planner Calendar starts quieter and matches Home's default treatment of assumed-done routines.
- Users can still inspect, hide, drag, or convert assumed-done activity after enabling the timed Calendar layer.
- Day agenda `Assumed done` sections continue to summarize matching synthetic assumed-done activity in the right sidebar without requiring the timed Calendar layer.
