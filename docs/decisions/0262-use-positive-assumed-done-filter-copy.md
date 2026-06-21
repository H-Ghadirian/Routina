# 0262: Use Positive Assumed-Done Filter Copy

## Status

Accepted

## Date

2026-06-21

## Refines

- [0260: Hide Assumed-Done Tasks by Default](0260-hide-assumed-done-tasks-by-default.md)
- [0261: Scope Done Today Filter to Routines](0261-scope-done-today-filter-to-routines.md)

## Context

Home hides assumed-done routine rows by default so the main task list stays
quiet. The previous filter label, `Don't show assumed done tasks`, described the
stored hidden-state flag directly, but it was harder to scan than a positive
visibility control.

Assumed-done presentation only applies to routines. Todos do not qualify for
auto-assumed completion, and completed todos leave the active task list for
Timeline.

## Decision

Home filter surfaces present the control as `Show assumed done`, defaulting off
because assumed-done rows remain hidden by default. The stored temporary view
state continues to use the existing hidden-state field for compatibility.

The `Show assumed done` control is shown only when the task type is `All` or
`Routines`. When task type is `Todos`, stale stored assumed-done visibility does
not count as an active filter and does not appear in active filter summaries.

## Consequences

- Users get positive filter copy while the quieter default list behavior stays
  unchanged.
- Todos-only filtering no longer exposes a routine-only visibility control.
- Existing temporary view state remains compatible because only the UI binding
  and presentation rules changed.
