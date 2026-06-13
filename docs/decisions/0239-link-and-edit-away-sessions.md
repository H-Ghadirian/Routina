# 0239: Link and Edit Away Sessions

## Status

Accepted

## Date

2026-06-13

## Refines

- [0125: Support Away Sessions](0125-support-away-sessions.md)
- [0148: Support Count-Up Away Sessions](0148-support-count-up-away-sessions.md)
- [0155: Link Away Activity in the Planner](0155-link-away-activity-in-planner.md)

## Context

Away sessions can represent real-world activity that is also tracked as a task, but inferred planner linking only works after overlapping task activity exists. Users also need to correct Away metadata while the protected session is running or after it has finished.

## Decision

Away sessions store an optional `linkedTaskID` as durable attribution metadata. Linking an Away to a task does not complete, cancel, miss, or otherwise mutate that task, and it does not merge Away history into task completion history.

Away start and edit surfaces can set or clear the linked task. The same editor can revise the title, preset, timer mode or duration, and timestamps for active or finished Away sessions. Timeline and planner presentation may use the linked task title and emoji to explain what the Away period was for while preserving Away as the owning session record.

## Consequences

- Users can label an active or historical Away with the task it supported without creating duplicate task history.
- Backup/import preserves the Away-task attribution with schema version 34.
- Planner linking remains presentational: Away blocks can show the linked task, but task stats still come from task logs and explicit time allocations.
