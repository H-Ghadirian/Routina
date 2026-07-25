# 0027 — Preserve detail across transient Add Task

Date: 2026-07-25

Revises the corrective approach recorded in [0026](0026-clear-detail-selection-on-transient-navigation.md).

## Symptom

After preventing Add Task from restoring an old task-list filter, returning to Tasks showed an empty `Select a task` detail surface instead of the task that had been open.

## Root Cause

The first fix cleared the shared selected-task state to prevent return-time task-list alignment. That state also owns the detail presentation, so filter preservation unintentionally discarded the user's task context.

## Fix

Add Task now retains the selected task while clearing only the visible sidebar selection. When navigation returns directly from Add Task to Tasks, it restores the selected row and detail but skips the task-type alignment that would restore another tab's filter snapshot.

## Prevention Rule

For transient overlays or workspaces, distinguish preserved content context from navigation side effects. Suppress the unwanted return transition directly instead of deleting the state needed to restore the underlying content.

## Regression Safeguard

The Mac Home feature test verifies all three return invariants together: the selected task detail is preserved, the `All` task-list mode remains active, and the created-date filter remains unfiltered.
