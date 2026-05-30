# 0103 Record Count-Up Focus Blocks at Elapsed Duration

- Status: Accepted
- Date: 2026-05-30
- Supersedes: [0102](0102-create-planner-blocks-when-task-focus-starts.md)

## Context

Countdown focus timers have a known intended duration when they start, so their planner block can use that duration immediately. Count-up timers are open ended: using the task estimate or the planner's ordinary 15-minute minimum makes the calendar block misleading when the user focuses for 3 minutes, 5 minutes, 131 minutes, or any other actual elapsed duration.

## Decision

Starting any task focus timer still creates a planner representation. Countdown timers persist a planner block with the selected countdown duration. Count-up timers persist a one-minute starter block, keep the active live focus overlay visible while running, and update the persisted planner block to the exact elapsed whole-minute duration when the timer finishes or is abandoned.

Focus-created planner blocks may store durations below the ordinary manual planner minimum. The normal manual planner controls and resizing behavior continue to use the 15-minute minimum.

## Consequences

- Count-up focus blocks match the timer's actual active duration instead of a task estimate.
- Very short focus sessions remain visible with a minimum rendered height even when their stored duration is only a few minutes.
- Planner block storage allows short focus-derived records while preserving the normal 15-minute manual planning interaction.
