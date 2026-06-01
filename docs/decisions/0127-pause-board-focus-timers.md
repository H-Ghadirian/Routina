# 0127 Pause Board Focus Timers

- Status: Accepted
- Date: 2026-06-01

## Context

Task and unassigned focus timers already support Pause, Finish, and Abandon controls. Board focus timers still counted wall-clock time from start to stop, and finishing one immediately opened allocation review, which made the board timer feel inconsistent with task focus and interrupted the user's flow.

## Decision

Board `SprintFocusSession` timers use the same active-time pause model as task focus timers: an active board focus session can be paused and resumed with `pausedAt` plus accumulated paused seconds, and finished board focus duration excludes paused intervals.

The board timer's active controls are Pause/Resume, Finish, and Abandon. Finish records the completed board focus session but does not automatically open allocation review; users can still allocate or review completed board focus from the session history. Abandon removes the active board focus session instead of saving it as completed history.

## Consequences

- Board focus timers match task focus timer controls and duration semantics.
- Completed board focus history represents focused time rather than paused wall-clock time.
- Allocation remains an explicit review action instead of an automatic finish-time interruption.
