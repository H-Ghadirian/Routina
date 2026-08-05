# 0001 — Make Importance and Urgency explicitly optional

Status: Deferred

## Current State

`RoutineTaskImportance` and `RoutineTaskUrgency` have legacy `Medium` defaults.
The iOS review procedures therefore persist independent
`hasExplicitImportance` and `hasExplicitUrgency` markers to distinguish
untouched defaults from values the person has made explicit.

## Target State

Add an explicit `None` value to Importance and Urgency. New task creation and
all durable drafts should default both fields to `None`; selecting a value in a
form or guided procedure should persist that chosen value.

## Required Migration Work

- Preserve existing stored values during schema, sync, backup, sharing, and
  import compatibility work; never infer that a legacy `Medium` was deliberate.
- Update task creation, quick-add, editing, filters, task details, derived
  Priority, and all cross-platform presentations to handle `None`.
- Replace the marker-based guided-review eligibility rule with direct selection
  of tasks whose Importance or Urgency is `None`, then retire markers only when
  migration compatibility no longer needs them.
- Add regression coverage for new defaults, an explicit Medium selection, and
  legacy tasks that retain Medium after the migration.

## Decision Link

[0475 Separate Guided Importance and Urgency Reviews](../decisions/0475-separate-guided-importance-and-urgency-reviews.md)
