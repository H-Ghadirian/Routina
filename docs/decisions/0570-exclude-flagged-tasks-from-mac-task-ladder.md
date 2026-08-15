# 0570: Exclude Flagged Tasks from the Mac Task Ladder

## Status

Accepted

## Date

2026-08-15

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0562: Exclude Blocked Tasks from the Mac Task Ladder](0562-exclude-blocked-tasks-from-mac-task-ladder.md)

## Context

Some active, actionable tasks should remain available in normal task surfaces
but should not participate in the deliberate ranking exercise of Task Ladder.
Lifecycle state cannot express that preference, and reusing the existing rule
for normal task-list visibility would also remove the task from Home.

## Decision

Flags can carry a separate synced `Hide tasks from Task Ladder` rule. A task
carrying any matching Flag is excluded from every Task Ladder metric and from
the ladder's count. The rule does not change the task, its lifecycle, its rank
keys, or its placement and behavior in Home, Backlog, Planner, Timeline, Stats,
notifications, or search.

The Task Ladder reads the current Flag rules when loading and rebuilds its
stable presentation snapshot when those saved rules change. Rule matching is
case-insensitive through the existing normalized Flag identity.

## Consequences

- Task Ladder visibility can be managed independently of normal task-list
  visibility.
- Removing the rule or the matching Flag makes an otherwise eligible task
  available to every Task Ladder metric again with its prior rank keys intact.
- The exclusion happens before Task Ladder sectioning, counting, and sorting,
  so scrolling rows continue to consume an immutable cached presentation.
