# 0042: Link Goals Into Hierarchies

## Status

Accepted

## Date

2026-05-14

## Context

Users need goals to relate to each other so a larger outcome can be broken into smaller sub-goals. Existing goal links only connected tasks to goals, so the Goals screen could not express parent/child outcomes.

## Decision

Each `RoutineGoal` may store one optional `parentGoalID`. Sub-goals are derived by looking up goals whose parent ID points at the current goal. The editor prevents choosing the current goal or one of its descendants as the parent, which keeps the hierarchy acyclic.

Goal hierarchy is platform-neutral. iOS and macOS use the shared editor state to choose a parent goal, and both goal detail views show parent and sub-goal links. Backup/import and CloudKit direct-pull support preserve and repair parent goal IDs.

## Consequences

- A goal can belong to at most one parent, keeping the mental model tree-shaped instead of graph-shaped.
- Deleting a parent goal keeps its sub-goals and clears their parent link.
- Future goal rollups can use the same parent ID to aggregate progress across sub-goals.
