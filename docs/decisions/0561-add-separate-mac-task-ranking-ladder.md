# 0561: Add a Separate Mac Task-Ranking Ladder

## Status

Accepted

## Date

2026-08-13

## Revised By

- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md) replaces the separate Task Ladder window with a full-size workspace inside the main Mac window while preserving the ranking behavior defined here.

## Context

Backlog intentionally organizes tasks kept away from the daily Home radar. It
must not become a second general task list. At the same time, a person may need
to inspect all active work through one task attribute and resolve meaningful
ties—for example, deciding the order of several Medium-pressure tasks—without
changing the order in any other task surface.

Estimated time is different: a 15-minute estimate has a factual numerical
relationship to a 16-minute estimate. Manual movement there would communicate a
false estimate rather than a personal preference.

## Decision

Mac has an independent `Task Ladder` window, opened from the Routinam menu. It
contains only active tasks: paused, snoozed, completed, canceled, and archived
tasks are excluded.

The window can present Pressure, Urgency, Importance, Thinking needed, and
Estimated time. Each categorical metric has visually distinct value sections
and a final, separate missing-value section. Importance and Urgency count as
missing until explicitly set, rather than treating their presentation defaults
as data.

Categorical sections are manual ladders. Move Up and Move Down operate in the
current displayed direction; crossing a value-section boundary intentionally
changes only the selected metric and positions the task in the destination
section. Each metric/value pair has an independent durable integer rank key.
Ranks are spaced, a move normally writes only the moved task, and a bucket is
renumbered only when needed to establish or restore space. The rank key is
synced and preserved by backup/restore. Existing neighbouring tasks therefore
do not need to change simply because a task is inserted between them.

Estimated time is a read-only numeric sort, with a separate `No estimate`
section. Reversing any metric changes only the presentation direction: it never
rewrites metadata or rank keys, and each metric remembers its own selected
direction. Its default directions are most-first for
Pressure, Urgency, and Importance; quick-wins-first for Thinking needed; and
shortest-first for Estimated time.

The ranking surface creates a stable presentation snapshot at data, metric, or
direction invalidation boundaries. Its scrolling rows consume that snapshot.

## Consequences

- Backlog remains a location for off-radar work and does not gain all-task
  ranking responsibilities.
- A task can have different intentional tie-break positions for every metric.
- Cross-device concurrent task moves rely on the persisted task-level order
  data and existing SwiftData/CloudKit last-writer synchronization behavior.
- Estimated time remains trustworthy as an estimate rather than a manual
  priority control.
