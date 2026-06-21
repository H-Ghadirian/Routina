# 0261: Scope Done Today Filter to Routines

## Status

Accepted

## Date

2026-06-21

## Refines

- [0216: Move Mac Home Task Type Tabs to Filter Screen](0216-move-mac-home-task-type-tabs-to-filter-screen.md)
- [0260: Hide Assumed-Done Tasks by Default](0260-hide-assumed-done-tasks-by-default.md)

## Context

Home task filters include task type and status filters. `Done Today` is useful
for routines because completed routines can still be relevant in the routine
list presentation. Completed todos leave the active task list and are represented
in Timeline instead, so a Todos + Done Today filter is an empty or misleading
state.

Selecting `Todos` or `Routines` from the Mac filter detail also changes the task
list scope, but the Mac sidebar clear affordance was only driven by status and
optional filters.

## Decision

The Home status filter offers `Done Today` only when the task type is `All` or
`Routines`. Switching or restoring task filters into `Todos` normalizes a stale
`Done Today` status filter back to `All`.

On macOS, selecting `Todos` or `Routines` counts as an active task filter for
the sidebar search/filter panel, so `Clear All Filters` appears above the task
list and resets task type back to `All`.

## Consequences

- The Todos filter surface avoids a status option whose matching completed todos
  live in Timeline rather than the task list.
- Restored temporary filter state cannot leave the user in a hidden Todos +
  Done Today combination.
- Mac users can return from task-type-scoped lists to the default combined list
  from the same clear affordance used for other task filters.
