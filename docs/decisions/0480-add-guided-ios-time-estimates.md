# 0480: Add Guided iOS Time Estimates

## Status

Accepted

## Date

2026-08-06

## Refines

[0473 Use Guided iOS Missing-Metadata Procedures](0473-use-guided-ios-missing-metadata-procedures.md),
[0478 Add Guided iOS Thinking Needed Review](0478-add-guided-ios-thinking-needed-review.md),
and [0476 Keep Guided Review Card and Detail Work Bounded](0476-keep-guided-review-card-and-detail-work-bounded.md)

## Context

Estimated duration is already optional task data. Missing estimates make time-
aware task choice less useful, but requiring people to open every full editor
to provide an estimate is slow and breaks the focused cleanup workflow.

## Decision

Compact iOS More includes `Add missing time estimates`. It shares the existing
field-parameterized missing-data reducer, full-height card, bounded task
context, Skip action, and Home Task Details route. Eligible tasks are repeating
tasks whose `estimatedDurationMinutes` is nil plus unfinished, uncanceled
one-off tasks with no estimate.

The card presents every existing duration preset directly—15m, 30m, 1h, 2h,
4h, 8h, and 20h—over two wrapped rows, plus always-visible custom Hours and
Minutes entry. Tapping a preset or entering custom time only creates a visible
temporary draft. An explicit `Save & next` action persists the positive
estimate and advances, so the person can verify their choice before the card
changes. The task detail editor remains the route for more involved edits.
This iOS-only MVP never changes actual time spent, priority metadata, planning,
scheduling, or order.

## Consequences

- Time estimates can be backfilled quickly without adding a second duration
  model or a scrolling list.
- The chooser can use more real estimates while unknown estimates remain
  neutral until this procedure is completed.
- Reusing the guided reducer preserves its bounded loading and detail-route
  performance guarantees.
