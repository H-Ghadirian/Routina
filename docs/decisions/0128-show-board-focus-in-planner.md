# 0128 Show Board Focus in Planner

- Status: Accepted
- Date: 2026-06-01

## Context

Task focus timers already leave visible planner evidence. Board focus timers are also deliberate calendar time, but they previously only appeared in board focus history and Timeline. That made sprint focus feel disconnected from the Planner, especially after users allocated finished board focus minutes back to sprint tasks.

## Decision

Planner shows sprint board focus sessions as focus blocks derived from `SprintFocusSessionRecord`. Active and finished unallocated board focus appears as a board focus block. When a finished board focus session has task allocations, allocated minutes render as task-colored focus blocks using the allocated task title and duration; any unallocated remainder stays visible as board focus.

Sprint focus planner blocks are derived from the persisted sprint focus session and allocation records instead of being independent manual planner blocks. They contribute blocked intervals so new planner drops cannot accidentally cover recorded sprint focus time.

## Consequences

- Starting and finishing board focus leaves calendar evidence in Planner.
- Reviewing allocation immediately updates the Planner representation without duplicating manual task blocks.
- Board focus history remains the source of truth, while Planner stays a readable projection of that recorded time.
