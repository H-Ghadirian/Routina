# 0376: Hide Probable Time From Assumed-Done Forms

## Status

Accepted

## Date

2026-07-12

## Refined by

[0398: Move Auto-Assume Done to Tracking](0398-move-auto-assume-done-to-tracking.md)

## Refines

- [0271: Use Probable Times for Assumed Planner Activity](0271-use-probable-times-for-assumed-planner-activity.md)
- [0367: Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md)
- [0368: Hide Assumed-Done Calendar Layer by Default](0368-hide-assumed-done-calendar-layer-by-default.md)
- [0369: Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)
- [0372: Hide Completed Tasks From Calendar Schedule](0372-hide-completed-tasks-from-calendar-schedule.md)

## Context

[0271](0271-use-probable-times-for-assumed-planner-activity.md) exposed a
`Probable time` picker because assumed-done routines could become automatic
Planner calendar activity. Later Planner decisions moved synthetic
assumed-done activity out of the editable Calendar Schedule and into
review-oriented day agenda/List sections.

Once assumed-done rows are no longer auto-placed on the editable calendar, a
visible probable-time control makes the auto-assume form feel more precise than
the behavior it now drives.

## Decision

Task creation and Task Detail editing expose only the `Auto-assume done` toggle
for eligible routines. They do not show a `Probable time` picker on iOS or
macOS.

The stored `autoAssumeDoneTimeOfDay` value remains data-compatible for existing
tasks, sync, import/export, and deterministic synthetic review timestamps. New
auto-assumed routines can continue using the default stored time when the
feature is enabled, but users do not edit that time from the standard task
forms.

Synthetic assumed-done activity must not be auto-placed into the editable
Calendar Schedule because of a probable time. It remains review-only until the
user confirms, misses, hides, or otherwise resolves the routine day.

## Consequences

- Auto-assume setup stays focused on the opt-in behavior instead of asking for
  calendar-placement precision the app no longer uses.
- Existing tasks and backups that carry custom probable times remain readable.
- If user-editable assumed-done timing becomes useful again, it should return as
  an explicit advanced behavior rather than a default form field.
