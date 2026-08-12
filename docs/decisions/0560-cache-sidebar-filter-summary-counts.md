# 0560: Cache Mac Sidebar Filter-Summary Counts

## Status

Accepted

## Date

2026-08-13

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

The Mac Home sidebar showed its active filter summary by separately scanning all
loaded task displays to count visible results. That computed property is
reached from SwiftUI's sidebar render path and can be evaluated while the
source list is scrolling. The task-list presentation already owns the
filtering result and is cached for the same inputs.

## Decision

`HomeTaskListPresentation` stores its visible task count when the immutable
presentation is constructed. Mac sidebar filter summaries read that count from
the existing task-list presentation cache instead of creating a second
whole-list filtering pass.

## Consequences

- A sidebar summary reuses the exact result count that the visible list
  renders, including task placement and search fallback behavior.
- Scrolling and normal SwiftUI body reevaluation do not trigger a separate
  per-task visibility scan for filter copy.
- Count calculation remains coupled to the snapshot invalidation inputs, so
  changes to tasks, filters, search, or display preferences refresh it
  together with the list.
