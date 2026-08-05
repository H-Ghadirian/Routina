# 0476: Keep Guided Review Card and Detail Work Bounded

## Status

Accepted

## Date

2026-08-05

## Refines

[0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md),
[0473 Use Guided iOS Missing-Metadata Procedures](0473-use-guided-ios-missing-metadata-procedures.md),
and [0475 Separate Guided Importance and Urgency Reviews](0475-separate-guided-importance-and-urgency-reviews.md)

## Context

Guided metadata procedures can have hundreds of eligible tasks. Rendering one
card must not retain or derive the tag, path, and label presentation for every
remaining candidate. Likewise, opening Task Details from a card and returning
to the procedure must not reload every task, place, goal, and historical log
that Home already loaded to present the selected task.

## Decision

Guided missing-data reducers retain their ordered candidate task IDs and the
presentation for only the visible task. Initial loading may query the eligible
IDs in deterministic title order, but creates the bounded card presentation
only for the first task. Save and Skip remove or rotate an ID, then fetch and
derive only the next visible card. The Importance and Urgency store predicate
includes their field-specific explicitness and legacy compatibility rules, with
the reducer retaining its semantic eligibility check before a write.

When Home selects a task for Task Details, its already-loaded snapshot provides
the edit context (goals, places, tags, rules, completion summaries, and
relationship candidates). Task Details marks that context as preloaded and
skips its standalone global edit-context fetch. Direct presentations without a
Home snapshot keep the standalone fallback. The selected task's logs and
attachments still load through their focused task-ID queries.

## Consequences

- Review state grows with compact IDs, while only one card carries display
  context at a time.
- Advancing a card uses a bounded single-task fetch instead of remapping the
  complete candidate set.
- Card-to-details round trips avoid repeated whole-store fetches while keeping
  standalone Task Details correct.
- The seeded UI performance path covers more than 250 review candidates and a
  large activity history; focused reducer and selection-router tests protect
  the structural boundary.
