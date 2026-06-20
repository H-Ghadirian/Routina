# 0260: Hide Assumed-Done Tasks by Default

## Status

Accepted

## Date

2026-06-20

## Refines

- [0216: Move Mac Home Task Type Tabs to Filter Screen](0216-move-mac-home-task-type-tabs-to-filter-screen.md)
- [0252: Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md)
- [0259: Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md)

## Context

Auto-assumed daily completion lets eligible routines default to done while still
allowing the user to confirm or mark the day as not today. Showing those rows in
the primary Home task list can make the list feel noisier because the routine is
already in its default completed presentation.

Users still need an escape hatch for review and correction, especially when they
want to confirm assumed days or decide that an assumed day should not count.

## Decision

Home task filters include a `Don't show assumed done tasks` option, checked by
default on new, reset, and legacy temporary filter state.

When checked, the shared Home task-list predicate hides rows whose current-day
presentation is only assumed done. When unchecked, assumed-done rows appear in
the task list and the active filter summary marks the non-default state as
`Assumed visible`.

The option lives in the existing Home filter surfaces on iOS and macOS and is
stored with temporary Home filter state, including per-task-list-mode snapshots.
This only changes Home list presentation; auto-assume eligibility, task detail,
calendar markings, confirmation, and not-today flows keep their existing
behavior.

## Consequences

- The default Home task list is quieter for users who opt routines into
  auto-assumed completion.
- Users can still show assumed-done tasks from Filters when they need to review,
  confirm, or correct them.
- Future Home task-list changes should keep this as part of the shared filter
  predicate instead of adding platform-specific filtering passes.
