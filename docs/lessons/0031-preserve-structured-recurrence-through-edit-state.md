# 0031 — Preserve structured recurrence through edit state

Date: 2026-07-26

## Symptom

Opening and saving a monthly calendar routine configured for multiple dates, such as the 1st, 15th, and 31st, silently reduced its recurrence to the first date. The edit form could also report a false unsaved change immediately after opening the task.

## Root Cause

The persisted recurrence model and Add Task form supported a collection of monthly dates, but Task Detail edit state represented the selection with only one `dayOfMonth` value. Form synchronization, change detection, and save reconstruction therefore discarded the remaining structured values.

## Fix

Task Detail edit state now carries the complete monthly-date collection alongside the scalar compatibility value. Loading, form bindings, candidate-rule derivation, change detection, and save reconstruction all use the normalized collection. An explicit edit through the single-date compatibility control intentionally replaces the collection with that one selected date.

## Prevention Rule

When a persisted domain value supports multiple selections, every intermediate edit representation and every reconstruction path must preserve the full collection. Scalar compatibility fields may provide fallback behavior, but they must never be the sole source for an untouched structured value.

## Regression Safeguard

`TaskDetailEditSaveTests.editSaveTapped_roundTripsMultipleMonthlyDatesAfterUnrelatedEdit` loads a three-date monthly rule into edit state, verifies that the untouched form is not falsely dirty, changes unrelated notes, saves, and confirms the exact structured rule survives persistence.
