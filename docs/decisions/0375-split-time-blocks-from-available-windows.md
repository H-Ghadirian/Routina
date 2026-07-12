# 0375: Split Time Blocks From Available Windows

Date: 2026-07-12

Status: Accepted

Refines: [0009 Support Routine Time Ranges](0009-support-routine-time-ranges.md), [0183 Support Todo Availability Time Windows](0183-support-todo-availability-time-windows.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0372 Hide Completed Tasks From Calendar Schedule](0372-hide-completed-tasks-from-calendar-schedule.md), [0373 Treat Window Availability as Non-Schedule Placement](0373-treat-window-availability-as-non-schedule-placement.md)

## Context

The single task-form `Window` timing choice was doing two different jobs in user language. Some windows are fixed commitments, like a meeting from 18:30 to 20:00, and users expect them to occupy that whole span on Planner Calendar `Schedule`. Other windows are flexible availability, like brushing teeth any time between 19:00 and midnight, and users expect those tasks to stay available without crowding the timed Schedule grid.

Decision 0373 correctly kept flexible windows out of Schedule, but the shared label made meeting-like blocks and availability-like windows indistinguishable.

## Decision

Task forms split the former `Window` timing into two time-range choices:

- `Time block` means the task happens during the whole start/end span. Planner Calendar `Schedule` creates a default timed block for unresolved task days, using the full range duration instead of the task estimate.
- `Available window` means the task can happen any time inside the start/end span. It remains availability metadata and does not create a default timed Schedule block.

`Any time`, `All-day`, and `At time` keep their existing meanings. `At time` continues to create a default timed Schedule block using the task estimate or default duration. Explicit Planner placements remain user-owned: dragging, dropping, or resizing one occurrence stores that Planner block and does not change all future occurrences.

Existing persisted time ranges default to `Available window` unless a new stored time-range role explicitly marks them as `Time block`.

## Consequences

- Meeting-like routines and todos can appear on Calendar `Schedule` by default without reviving automatic blocks for flexible availability windows.
- Availability-window cleanup from 0373 still removes stale old auto-window blocks when they exactly match the old generated placement, while manually moved or resized blocks remain.
- Backup, import, direct CloudKit pull, and task sharing preserve the time-range role so fixed blocks do not silently become flexible windows on another device or after restore.
