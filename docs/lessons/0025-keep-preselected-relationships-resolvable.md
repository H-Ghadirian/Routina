# 0025 — Keep preselected relationships resolvable

Date: 2026-07-25

## Symptom

Choosing `Add Linked Task` from Task Details opened Add Task with its Linked tasks section visible, but the section said there were no linked tasks.

## Root Cause

The routing state stored the intended inverse relationship while excluding its source task from `availableRelationshipTasks`. The form resolves relationship rows through that candidate collection, so it could not render the preselected relationship.

## Fix

The linked-task creation route now includes the source task in the Add Task relationship candidates. The existing selected-ID filtering still prevents the picker from offering that task as a duplicate link.

## Prevention Rule

Whenever a form is seeded with selected model references, every selected reference must also be present in the collection used to resolve its display metadata.

## Regression Safeguard

The shared router test and platform Home feature tests verify that linked-task creation includes both the inverse relationship and the source-task candidate. The linked-task creation scenario is also recorded in `docs/scenarios/README.md`.
