# 0636: Replace Configurable Flags With Built-In Behaviors

## Status

Accepted

## Date

2026-08-22

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)
- [0588: Configure Flag Rules by Assignment](0588-configure-flag-rules-by-assignment.md)

## Context

Configurable Flags allowed one personal name to carry several behavior rules,
but the combination was difficult to understand and configure. Routina has not
released a public version with this model, so the only affected records are
the person's own pre-release data. A task can also carry more than one Flag,
and overlapping rules must remain additive during the transition.

## Decision

Routina uses one fixed built-in Flag for each behavior rule: hide from normal
task lists, hide from Timeline, hide from Task Ladder, and auto-assume done.
People can assign any combination of these built-ins to a task. Settings lists
the four behaviors and no longer offers custom Flag creation, deletion, or
rule menus; ordinary personal labels are Tags instead.

The pre-release personal store was converted once before this behavior shipped:
each legacy Flag with one or more rules became the corresponding built-in Flag
assignment, overlapping rules were deduplicated, and a legacy Flag with no rule
became a Tag on each task that carried it. That conversion code is now retired;
the app no longer scans all tasks or stores a migration marker. Launch only
initializes or repairs the four canonical catalog values, without changing task
assignments.

## Consequences

- A task's behavior is visible directly from its assigned built-in Flags.
- Existing multi-rule and overlapping assignments retain their combined effect.
- Unruled personal labels remain searchable and organizable as Tags.
- Backup and sync continue to carry the existing string Flag and typed-rule
  shapes, now populated with canonical built-in values.
- Future behavior additions require a product decision and a new built-in kind,
  rather than another user-configurable rule editor.
