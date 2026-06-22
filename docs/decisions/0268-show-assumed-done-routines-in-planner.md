# 0268: Show Assumed-Done Routines in Planner

## Status

Accepted

## Date

2026-06-22

## Refines

- [0005: Show Timeline Activity in the Day Planner](0005-show-timeline-activity-in-day-planner.md)
- [0094: Suggest Only Completed Activity in Planner Calendar](0094-suggest-only-completed-activity-in-planner-calendar.md)
- [0259: Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md)
- [0260: Hide Assumed-Done Tasks by Default](0260-hide-assumed-done-tasks-by-default.md)

## Context

Auto-assumed daily completion lets eligible routines default to done without
writing completion history until the user confirms the day. Home hides those
rows by default so the task list stays quiet, but Planner is a calendar surface
for what happened or is assumed to have happened during the day.

Planner already treats completed timeline activity as automatic calendar
evidence, including activity that has not been manually planned yet. Assumed
done routine days should participate in that planner view without pretending
that a persisted completion log already exists.

## Decision

Planner automatic activity includes eligible assumed-done routine days as
completed planner activity. These entries use a synthetic source keyed by task
and day so users can hide them from Planner without creating or editing routine
logs.

Dragging an assumed-done planner activity into the timed planner creates a
normal planner block for that task and time. It does not move completion
history or create a fake completion log. Confirming the assumed routine remains
the Task Detail action that records history and stats.

Home task list filters continue to hide assumed-done rows by default; this
decision changes Planner presentation only.

## Consequences

- Users can see assumed daily routine work on Planner even when Home keeps the
  task list quiet.
- Planner can still hide individual assumed activity cards with the same
  dismissal model as other automatic planner activity.
- Completion history remains honest: assumed days become logs only when the
  user confirms them.
