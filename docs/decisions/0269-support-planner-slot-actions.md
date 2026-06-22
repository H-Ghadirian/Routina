# 0269: Support Planner Slot Actions

## Status

Accepted

## Date

2026-06-22

## Refines

- [0008: Confirm Timeline Activity as Planner Blocks](0008-confirm-timeline-activity-as-planner-block.md)
- [0125: Support Away Sessions](0125-support-away-sessions.md)
- [0155: Link Away Activity in the Planner](0155-link-away-activity-in-planner.md)
- [0205: Run Plan Focus From Planner](0205-run-plan-focus-from-planner.md)
- [0239: Link and Edit Away Sessions](0239-link-and-edit-away-sessions.md)

## Context

Apple Calendar lets users click a timed slot and immediately create an event. Routina's Planner looks calendar-like, but its records are not generic calendar events: task blocks represent planned work, Away is protected session history, Focus has its own timer/allocation semantics, and standalone events are read-only planner records once created.

Users still need the calendar grid itself to be a fast capture surface. Selecting a date and time should offer the natural Routina actions for that slot without collapsing these separate models into a generic event object.

## Decision

Clicking an empty timed Planner slot continues to select that date and start time, resolving the pointer location to the same 15-minute grid used by drag/drop. It now also opens a compact slot action panel near the selected time. The panel can create a task planner block for a selected task and duration, using the existing `DayPlanBlock` persistence path and respecting existing planner-block and protected-interval conflicts.

The same panel can log Away for a finished interval. This creates a completed `AwaySession` with preset, optional title, optional linked task, selected start time, and selected duration. Away logging rejects intervals that overlap existing Sleep, Focus, Sprint Focus, or Away sessions. The slot panel does not create future scheduled Away reservations, does not start live Away protection for an arbitrary calendar time, and does not create standalone `RoutineEvent` rows.

## Consequences

- Planner slots become direct action targets while preserving the existing sidebar editor workflow.
- Future calendar blocking remains task-block based unless a future decision introduces scheduled Away or another reservation model.
- Away stays tied to protected-session history and stats, so the Planner cannot silently create future completed Away records.
- Overlap checks remain model-aware: task blocks avoid planned/protected conflicts, and logged Away avoids protected-session conflicts.
