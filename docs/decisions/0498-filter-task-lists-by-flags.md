# 0498: Filter Task Lists by Flags

## Status

Accepted

## Date

2026-08-07

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)

## Context

Flags now distinguish task behavior from organizational tags. People also need
to find the tasks assigned a particular Flag, including tracking-style tasks
whose Flag rule normally removes them from task lists.

Text search can find those tasks, but it is not a durable, composable task-list
filter and does not offer the familiar tag-filter interaction.

## Decision

Home task-list Filters include a task-only Flags section. People can select one
or more assigned Flags and choose `All` or `Any` matching. The selection is
stored in each task-list mode's temporary filter snapshot, participates in
active-filter summaries and chips, and is cleared with the other optional
task-list filters.

The choice catalog is derived and cached when Home refreshes its task display
snapshots. It contains Flags assigned to available tasks, with per-list counts;
the scrolling view only reads that cache.

A Flag's behavior rule still controls ordinary placement. When a selected Flag
matches a task hidden by `Hide tasks from normal task lists`, Home deliberately
shows that task only in the existing presentation-only `Hidden by flag` result
section. It does not restore the task to a normal section or its inline
completion action. The Flag filter applies to Home task lists, not the Board,
Planner, Timeline, or Stats.

## Consequences

- A tracking-style Flag can be used as a focused task-list view without making
  its tasks part of ordinary Home placement.
- `All` and `Any` matching use normalized Flag identities, so capitalization
  and surrounding whitespace do not create separate filter behavior.
- Flag catalog and predicate work occur in the existing refresh/filter pipeline
  rather than adding whole-history work to SwiftUI render paths.
