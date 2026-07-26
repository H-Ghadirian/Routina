# 0441 — Enter Custom Calendar List Done Durations

Status: Accepted

Date: 2026-07-27

Refines: [0435 Edit Calendar List Done Times From Mac Task Detail](0435-edit-calendar-list-done-times-from-mac-task-detail.md)

## Context

The Mac Planner Calendar `List` task-detail companion pane already lets users
correct a recorded completion's start time and actual duration. Duration was
limited in the interface to common presets and a 15-minute stepper, even though
completion logs store positive whole-minute values. Durations such as 7, 22, or
67 minutes could not be entered directly from that context.

## Decision

The `Done this day` card exposes direct Hours and Minutes fields for actual
duration. Users can enter any whole-minute duration that is valid for the
selected start time and finishes within the selected calendar day.

Common presets and incremental adjustment remain available for convenience.
Changing the start time clamps an existing duration only when needed to keep
the completion inside the selected day. The minimum duration is one minute.

Saving continues to update only the exact completion occurrence carried from
the selected Calendar `List` Done row. It derives the completion timestamp from
start plus duration and does not mutate Planner blocks, planned rows,
recurrence, availability, reminders, estimates, or other occurrences.

## Consequences

- Actual duration is no longer restricted to preset or 15-minute increments.
- Existing completion identity and persistence behavior remain unchanged.
- No persistence migration is required.
