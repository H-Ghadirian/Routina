# 0050: Suggest Goal Task Links From Tags

- **Status:** Accepted
- **Date:** 2026-05-14

## Context

Goals can now carry tags, and tasks already carry tags and goal links. That creates a useful implied relationship: if a goal and an unlinked task share a tag, the task may belong under the goal. Automatically linking those tasks would be too aggressive because tags can also describe context, area, or tooling.

## Decision

Goal details derive suggested tasks from unlinked tasks whose tags overlap the goal's tags. Suggestions are not stored as separate records; they are calculated from current goal tags, task tags, and existing task goal links.

Accepting a suggestion adds the goal ID to the task's goal links. Rejecting a suggestion stores that task ID on the goal as a dismissed suggestion so the same task does not reappear for that goal. Dismissed suggestion IDs are included in backup, import, and CloudKit direct-pull repair data.

## Consequences

- Suggestions stay fresh when tags change without maintaining a duplicate suggestion table.
- Rejections are scoped to one goal, so the same task can still be suggested for a different matching goal.
- Backup and sync must preserve dismissed suggestion IDs so user intent survives restore and cross-device repair.
