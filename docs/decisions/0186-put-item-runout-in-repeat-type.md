# 0186: Put Item Runout in Repeat Type

## Status

Accepted

## Date

2026-06-08

Refines [0176](0176-nest-runout-under-checklist-cadence.md) and [0177](0177-separate-interval-and-calendar-repeat-controls.md) for routine checklist scheduling.

## Context

Decision 0176 moved Runout out of the top-level Completion control and into a separate Checklist cadence control. That reduced one source of confusion, but it still left checklist routines with two adjacent cadence decisions:

- Checklist cadence: Together or Runout.
- Repeat type: Interval or Calendar.

That made Runout look like a second scheduling path instead of one of the repeat strategies available to checklist routines.

## Decision

Routine forms keep Completion as `Standard` or `Checklist`.

When Completion is `Checklist`, the Repeat type control shows:

- `Interval`: checklist items finish together on the routine's interval cadence.
- `Calendar`: checklist items finish together on the routine's calendar cadence.
- `Item runout`: checklist items carry their own timing, and the earliest due item drives the routine.

The separate Checklist cadence control is removed from task forms. The stored `RoutineScheduleMode` and `RoutineFormat` values remain unchanged: selecting `Item runout` still stores the runout schedule modes, while selecting `Interval` or `Calendar` stores the checklist schedule modes.

## Consequences

- Checklist routines have one cadence control instead of two.
- Runout is presented as a repeat strategy, not as another completion mode.
- Existing runout tasks continue to load as checklist routines with Repeat type set to `Item runout`.
- Persistence, sync, parser output, and completion logic can continue branching on runout schedule modes where behavior differs.
