# 0110: Show Goal Momentum Stats

## Status

Accepted

## Date

2026-05-31

## Context

Goals can be linked to tasks, and Stats already fetches goals, tasks, logs, and focus sessions. Goal summary cards show counts, but they do not reveal which goals are receiving completed work or focused time in the selected Stats range.

## Decision

Stats includes a Goal Momentum section for active goals with linked tasks. The section shows linked-task completion coverage, completed activity count, and focus time for each goal using the same selected range and task filters as the rest of Stats.

Completed tasks are counted by distinct linked task IDs with completed logs in the selected range. Completion count keeps repeated completed activity visible. Focus time is summed from completed focus sessions on linked tasks. If a task is linked to multiple active goals, its completions and focus time contribute to each linked goal.

## Consequences

- Users can see which active goals are getting attention without opening each goal detail.
- The section remains factual and filter-preserving rather than generating narrative insight text.
- Goals without linked tasks are omitted until they have actionable work attached.
