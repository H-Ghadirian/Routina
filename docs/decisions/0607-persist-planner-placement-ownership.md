# 0607 — Persist Planner placement ownership

Status: Accepted

Date: 2026-08-18

Refines: [0375: Split Time Blocks From Available Windows](0375-split-time-blocks-from-available-windows.md)

## Context

Planner must update an automatically generated timed block when its task schedule changes, while preserving a block the person deliberately moved or resized. Comparing a block only with the task's previous scheduled time is insufficient: once one update is missed, the stale block no longer matches the previous schedule on the next edit and can remain wrong indefinitely.

## Decision

Persist placement ownership with each timed Planner block. Blocks generated from exact task schedule metadata are `automatic`; blocks created, moved, resized, duplicated, or explicitly committed through Planner are `manual`. Schedule edits rebase automatic blocks regardless of whether their current coordinates still match the immediately previous schedule.

For an existing automatic block, task schedule metadata is authoritative even when the new interval overlaps another planned block; leaving it at an unrelated old time would misrepresent the task. New free placement and automatic-block creation continue to use their existing conflict checks.

Existing records without provenance are `legacy`. A legacy record is treated as automatic when it either matches the previous generated placement or still has identical creation and update timestamps, which identifies an untouched generated block. Once reconciled, it is persisted as automatic. Other legacy records remain user-owned.

Backup and import preserve the placement source. Older backups without it import as legacy and use the same compatibility rules.

## Consequences

- A stale untouched automatic block can recover after an earlier missed update instead of remaining permanently detached from task details.
- Manual Planner placement remains independent from future task schedule edits.
- New block-producing and block-editing paths must set the ownership source deliberately rather than inferring it from coordinates.
