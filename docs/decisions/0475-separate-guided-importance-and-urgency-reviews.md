# 0475: Separate Guided Importance and Urgency Reviews

## Status

Accepted

## Date

2026-08-05

## Supersedes

[0474 Use Task Detail Priority Visibility for Guided Metadata Review](superseded/0474-use-task-detail-priority-visibility-for-guided-metadata-review.md)

## Refines

[0424 Make Task Detail Priority Optional](superseded/0424-make-task-detail-priority-optional.md)
and [0473 Use Guided iOS Missing-Metadata Procedures](0473-use-guided-ios-missing-metadata-procedures.md)

## Context

The combined review required two compact menus followed by `Save & next`, so a
person could not see all available choices before interacting. It also marked
both matrix fields reviewed after a single combined save, even when a person
only wanted to decide Importance or Urgency.

Legacy tasks still persist `Medium` as the default for both fields, so raw
values alone cannot distinguish an untouched default from an explicit Medium
selection.

## Decision

Compact iOS More exposes separate `Review Importance` and `Review Urgency`
procedures. Each procedure presents one full-height card at a time with the
task title, bounded context, and all four values visible as a two-by-two direct
selector. Selecting a value saves it immediately and advances; the card also
offers `Skip` and `Check task details`.

`RoutineTask` records `hasExplicitImportance` and `hasExplicitUrgency`
independently. A guided procedure sets only its own marker and recomputes the
derived Priority. Task Details shows the Priority section when either marker is
explicit, and field-specific eligibility keeps the other procedure available
until its own value is explicit. The legacy overall Priority flag and a legacy
non-neutral Priority remain compatible evidence that both fields were already
reviewed.

Both procedures load only lifecycle-eligible candidates: recurring tasks at
any completion state and one-off tasks only while unfinished and not canceled.
The reducer owns all SwiftData loading and writes; the iOS view has no direct
data access.

The legacy `Medium` defaults remain unchanged for now. The future migration to
explicit `None` values and direct `None`-based eligibility remains in [debt
ticket 0001](../debt/0001-make-importance-and-urgency-explicitly-optional.md).

## Consequences

- Importance and Urgency can be reviewed independently without accidental
  completion of the other review.
- Explicit Medium choices remain durable and distinguishable until the `None`
  migration.
- Backup, import, sharing, Task Details, and Quick Add preserve the explicit
  markers.
- The compact iOS procedures share one field-parameterized reducer while
  remaining separate user-facing destinations.
