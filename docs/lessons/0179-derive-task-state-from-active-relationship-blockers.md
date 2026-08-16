# 0179 — Derive task state from active relationship blockers

Date: 2026-08-16

## Symptom

Task Details showed a one-off task as `Ready` while its Linked Tasks section
showed that the same task was blocked by an unfinished prerequisite.

## Root Cause

Completion eligibility and the linked-task explanation used the resolved
relationship graph, but both platform State controls read only the task's
stored Todo state. The independently correct presentation paths therefore
contradicted one another.

## Fix

Shared Task Detail presentation now derives an effective Todo state. An active
confirmed prerequisite temporarily presents stored Ready or In Progress as
Blocked without mutating the stored workflow state. iOS and macOS use that
derived state, reveal State automatically for the blocker, withhold Ready and
In Progress until it resolves, and avoid attributing stored-state timing to the
relationship-derived block.

## Prevention Rule

When availability depends on related records, every state label, choice list,
and timing explanation on the same surface must use one relationship-aware
presentation value. Do not combine a graph-aware action predicate with a
graph-unaware state label.

## Regression Safeguard

`TaskDetailTodoStateTests` verifies effective blocking, restoration of the
stored state, and lifecycle precedence. `TaskDetailSharedViewSupportTests`
guards that both platform views use the shared effective state, choice list,
visibility rule, and timing treatment. The Task Detail State Reflects
Unresolved Prerequisites scenario records the cross-platform behavior.
