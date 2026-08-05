# 0474: Use Task Detail Priority Visibility for Guided Metadata Review

## Status

Accepted

## Date

2026-08-05

## Refines

[0424 Make Task Detail Priority Optional](0424-make-task-detail-priority-optional.md)
and [0473 Use Guided iOS Missing-Metadata Procedures](0473-use-guided-ios-missing-metadata-procedures.md)

## Context

Importance and Urgency are stored together as the task Priority matrix. Existing
tasks use legacy `Medium` defaults, so either raw field alone cannot say whether
a person deliberately selected `Medium`. Task Details already owns a durable
answer: it hides the matrix only while all values are neutral and the person has
not explicitly revealed Priority.

## Decision

Compact iOS More includes `Review Importance & Urgency`. It uses the existing
one-card-at-a-time procedure layout, with the task title, bounded context, two
compact value menus, `Save & next`, `Skip`, and `Check task details`. Saving
persists both values, recomputes the derived Priority, and sets the existing
`showsTaskDetailPriority` flag so even an explicit `Medium` / `Medium` choice
becomes visible in Task Details and does not re-enter the procedure.

Eligibility is defined by `TaskDetailOptionalControlVisibility.showsPriority`:
a task needs review exactly when that function returns false. The reducer loads
only lifecycle-eligible candidates and applies that shared visibility rule
before presenting or saving. As with Pressure, repeating tasks remain eligible
regardless of their current completion state, while one-off tasks must be
unfinished and uncanceled.

The legacy `Medium` defaults remain unchanged for now. The planned migration to
explicit `None` values, and the future change to select tasks directly by those
values, is recorded in [debt ticket 0001](../debt/0001-make-importance-and-urgency-explicitly-optional.md).

## Consequences

- The procedure recognizes explicit Medium choices without a new temporary
  marker or an ambiguous raw-value heuristic.
- Task Details and the review procedure share one definition of completed
  priority metadata.
- The current flow is available only on compact iOS, while the reducer stays in
  SharedCore for future reuse.
