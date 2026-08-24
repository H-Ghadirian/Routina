# 0651: Keep Task Focus Separate From Actual Time

## Status

Accepted

## Date

2026-08-24

## Context

Task Focus sessions and actual time answer different questions. Focus records a
bounded attention session, while actual time records how long a task or a
specific routine completion took.

Mac Task Details previously copied every finished task Focus duration into a
todo's task-level actual time or the latest completed routine log. That
attribution was implicit, could select the wrong routine occurrence, differed
from iOS, and became inaccurate when the Focus session was later edited or
deleted. It also contradicted the factual Estimated vs Actual reporting
contract in [0112](0112-show-estimated-actual-time-stats.md).

Planner Plan Focus is a distinct workflow: its explicit allocation surface
lets the person split elapsed Focus time across chosen planned tasks and keeps
durable attribution evidence, as defined by
[0209](0209-allocate-plan-focus-while-running.md).

## Decision

Finishing, editing, or deleting a task Focus session does not change
`RoutineTask.actualDurationMinutes` or `RoutineLog.actualDurationMinutes`.
Task Focus remains a `FocusSession` on iOS and macOS, and manually recorded
actual time remains authoritative completion evidence.

Any future conversion from task Focus into actual time must be an explicit
person-initiated action. For a routine, that action must identify the intended
completion occurrence and retain enough provenance to reconcile later Focus
edits or deletion.

Planner Plan Focus allocation remains the existing exception because the
person explicitly chooses task allocations and the Planner stores their
attribution evidence.

## Consequences

- Finishing the same task Focus has the same time-spent behavior on iOS and
  macOS.
- A Focus session cannot silently inflate a todo total or the latest routine
  completion.
- Editing or deleting Focus history cannot leave an untraceable copied actual
  duration behind.
- People who want actual time recorded continue to use the explicit Log/Add or
  Edit total controls, while Plan Focus allocation keeps its deliberate
  multi-task workflow.
