# 0593: Show Relationship Blocking in Home Task Rows

## Status

Accepted

## Date

2026-08-16

## Refines

- [0038: Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0486: Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md)

## Context

A one-off task with an unresolved confirmed prerequisite is effectively blocked,
and Task Details already presents that derived state without overwriting the
task's stored Ready or In Progress workflow state. Home task rows still rendered
the stored state, so the list could label the same selected task `To Do` or
`In Progress` while its details said `Blocked`. A person had to open each task to
discover that it could not yet be acted on.

Computing relationship resolution inside a row builder would correct the label
but violate Home's scrolling-performance boundary by repeatedly walking the task
graph during rendering.

## Decision

On iOS and macOS, a Home task row's Status Badge shows `Blocked` when a one-off
task has an unresolved confirmed `Blocked by` prerequisite. The derived badge
replaces `To Do` or `In Progress`; completing or canceling every prerequisite
restores the badge for the task's unchanged stored workflow state. Completed,
canceled, and paused lifecycle presentation keeps precedence.

Relationship resolution happens once while Home rebuilds its display snapshot.
Each row reads the cached `hasActiveRelationshipBlocker` value and never resolves
relationships from the SwiftUI render path. The existing Status Badge visibility
preference governs the derived badge just like every other task-row status.

## Consequences

- The task list and Task Details no longer contradict one another about whether
  work is currently blocked.
- Resolving a prerequisite reveals the earlier Ready or In Progress state without
  mutating task state or history.
- People who hide Status Badge keep their chosen row density.
- Snapshot rebuilding performs one bounded relationship pass; scrolling performs
  no relationship traversal.
