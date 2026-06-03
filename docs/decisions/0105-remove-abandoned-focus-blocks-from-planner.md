# 0105 Remove Abandoned Focus Blocks from Planner

- Status: Accepted
- Date: 2026-05-30
- Supersedes: [0103](superseded/0103-record-count-up-focus-blocks-at-elapsed-duration.md)

## Context

Starting a task focus timer creates a planner block because the user has committed calendar time to that task. If the user cancels or abandons that timer, the calendar allocation is no longer accepted time and should not stay behind as a planned block.

Sleep mode can also abandon active task focus timers when the user starts sleep while a focus timer is still running.

## Decision

Finishing a countdown focus timer keeps its selected countdown block. Finishing a count-up focus timer updates its persisted planner block to the exact elapsed whole-minute duration.

Abandoning or canceling any task focus timer removes the focus-created planner block whose id matches the `FocusSession` id. Starting sleep removes the task focus planner blocks for any active task focus timers it abandons.

Finished focus sessions remain focus history. Abandoned sessions should not leave planner blocks behind.

## Consequences

- Accidental or canceled focus timers do not leave calendar clutter.
- Manual planner blocks are not removed because cleanup only targets the focus-created block id.
- Sleep and focus remain non-overlapping without preserving abandoned task focus blocks in the planner.
