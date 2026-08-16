# 0582: Hide Flagged Task Activity From Timeline by Default

## Status

Accepted

## Date

2026-08-16

## Revises

- [0498: Filter Task Lists by Flags](0498-filter-task-lists-by-flags.md)

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0548: Keep iOS Stats and Timeline Filter Details in Sheets](0548-keep-ios-stats-and-timeline-filter-details-in-sheets.md)

## Context

Some tasks produce useful history without belonging in the person's ordinary
Timeline. Deleting that activity or globally excluding the task would lose
truthful history, while making the activity permanently invisible would make
later review and correction difficult.

Flags already express task behavior and provide a deliberate way to recover
otherwise hidden task-list results. Timeline needs the same reversible pattern
without performing new catalog or filter work while rows scroll.

## Decision

Settings -> Flags offers a `Hide task activity from Timeline` rule. With no
Timeline Flag filter selected, task completion, missed, canceled, and
task-linked Focus entries carrying that Flag are omitted from both the iOS
Timeline and the Mac Planner Timeline. The task, its history, notifications,
Planner Calendar placement, Stats, and other record types remain unchanged.

Timeline Filters includes a Flags section with `All` / `Any` matching.
Selecting one or more Flags is an explicit request to reveal matching
task-backed activity, including activity normally hidden by this rule. Clearing
the Flag selection restores the default Timeline. Text search and unrelated
filters do not bypass the rule.

The available-Flag catalog is derived from the pre-hide Timeline snapshot so a
person can still discover and select a Flag whose matching activity is hidden.
Flag filtering and the resulting grouped sections are rebuilt only at the
existing snapshot-refresh boundary, and the scrolling view reads the cached
presentation.

The selected Timeline Flags and match mode are temporary view state. Flag rules
retain the existing durable settings, sync, backup, and restore behavior.

## Consequences

- A behavior-heavy or private task can stay out of the ordinary Timeline while
  its history remains intact and deliberately recoverable.
- Selecting a Flag changes Timeline from its default view to a focused view of
  matching task activity; nonmatching contextual records are not included.
- A task-linked Focus entry follows the task's Flags, while unassigned Focus,
  events, notes, emotions, sleep, away, and place entries are not hidden by this
  task rule.
- Timeline Flag catalogs and row presentations remain compatible with the
  whole-history render-path boundary.
