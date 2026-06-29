# 0088: Support an Ungrouped Home Task List

## Status

Accepted

## Date

2026-05-27

Refined by: [0314 Remove Status Grouping and Collapse Deadline Groups](0314-remove-status-grouping-and-collapse-deadline-groups.md)

## Context

Home list grouping helps users scan by status, deadline, or tag, but sometimes those section headers add friction when the user wants one continuous list that still respects the active search and filters.

## Decision

Home list grouping includes a `None` mode. In this mode, active unpinned routines and todos render together in a single `Tasks` section using the normal task sort order. Daily routines are not split into their own section while ungrouped.

Pinned and archived rows remain separate lifecycle sections so priority and archival affordances stay predictable.

## Consequences

- Users can choose a flat task list without changing task data or disabling filters.
- Existing Status, Deadline Date, and Tags grouping semantics remain available.
- Manual ordering in `None` mode resolves within one shared active task section.
