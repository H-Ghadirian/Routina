# 0007 Show Active Focus Timers in the Planner

- Status: Accepted
- Date: 2026-05-09

## Context

Starting a focus timer from task details represents work that is happening now. The planner calendar should reflect that active allocation immediately and keep it visually current while the timer runs.

## Decision

Active `FocusSession` records are rendered in the planner as live calendar blocks derived from the session start time and the current time. These blocks are not saved as `DayPlanBlockRecord` entries. The planner updates their visible duration from the calendar's existing minute-based `TimelineView`, and tapping a live block opens the related task details.

When a session is completed or abandoned, it stops being rendered as a live planner block. Completed focus time remains represented by the focus session history rather than being converted into a scheduled planner block.

## Consequences

- The planner stays in sync with task detail timers without duplicating planner data.
- Live focus blocks can lag real elapsed time by up to one minute, which keeps the calendar lightweight while still feeling current at planner scale.
- Finished focus sessions remain separate from timeline completion/missed/canceled activity unless a future decision adds focus history as planner activity.
