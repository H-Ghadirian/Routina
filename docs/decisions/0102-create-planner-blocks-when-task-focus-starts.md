# 0102 Create Planner Blocks When Task Focus Starts

- Status: Accepted
- Date: 2026-05-30
- Supersedes: [0007](0007-show-active-focus-timers-in-planner.md)

## Context

Starting a focus timer from task details is also a planning act: the user has decided to allocate calendar time to that task now. The previous behavior rendered active focus as a live derived planner block only while the timer was running, then removed it when the session ended.

Users expect pressing a task focus timer to put that task onto the calendar planner as a real block they can later see and adjust.

## Decision

Starting a task `FocusSession` from task details creates or reuses a persisted `DayPlanBlockRecord` on the timer start day. New focus-created blocks use the `FocusSession` id as the planner block id, start at the session start minute, and use the selected countdown duration. Count-up timers use the task estimate when present, falling back to the planner minimum duration.

If an overlapping planner block for the same task already exists, Routina treats that block as the planner representation instead of adding a duplicate. Active focus sessions that are not represented by a persisted planner block can still render through the live derived fallback, and live overlays are suppressed when a matching planner block is already visible.

Finishing or abandoning the focus session does not create another planner block. The focus history remains the source of truth for recorded focus duration.

## Consequences

- Starting focus from task details immediately persists visible calendar planner intent.
- Existing live focus rendering still covers older or externally created active sessions that do not have planner blocks.
- Count-up sessions need an initial planner duration even though their true duration is open ended; task estimate provides that default when available.
