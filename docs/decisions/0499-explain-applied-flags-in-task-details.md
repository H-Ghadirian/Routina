# 0499: Explain Applied Flags in Task Details

## Status

Accepted

## Date

2026-08-07

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)
- [0498: Filter Task Lists by Flags](0498-filter-task-lists-by-flags.md)

## Context

Flags deliberately carry application behavior, unlike organizational tags. A
task opened from Home's presentation-only `Hidden by flag` section previously
showed only that generic section name in its Mac sidebar breadcrumb, leaving
the person unable to tell which assigned Flag caused the placement. Task
Details also omitted Flags entirely, so the task's behavior was not inspectable
from the task itself.

## Decision

Task Details show every Flag assigned to the task on iOS and macOS, using a
distinct Flag chip treatment. The task-list result section retains its generic
`Hidden by flag` title because it may contain tasks hidden by different Flags.
When a Mac Task Detail breadcrumb is derived from that result section, it names
the matching hiding Flag or Flags for that one task.

## Consequences

- People can inspect a task's assigned behavior markers without opening Edit
  Task or Settings.
- The Mac breadcrumb describes the selected task precisely without changing
  the shared section's cached identity or membership.
- Flag labels remain descriptive only: they do not change the existing hiding,
  filtering, search, or task-list placement rules.
