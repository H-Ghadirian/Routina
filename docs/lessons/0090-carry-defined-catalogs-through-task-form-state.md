# 0090 — Carry defined catalogs through task-form state

Date: 2026-08-07

## Symptom

A flag defined in Settings did not appear as a suggestion when creating or editing a task.

## Root Cause

The Flags feature persisted its catalog, but Add Task and Edit Task only received selected task flags and their draft text. The defined-flag catalog was never loaded into their form state or rendered by the flag editor.

## Fix

Defined flags now flow through Add Task and Edit Task state into selectable, bounded suggestion chips on iOS and macOS. Add Task drafts also preserve their selected flags without replacing the live catalog.

## Prevention Rule

When a Settings-owned catalog is used by an editor, explicitly carry the catalog through that editor's state and its presentation model; persisting it alone is not sufficient.

## Regression Safeguard

`HomeFeatureAddRoutinePresentationRouterTests` verifies a new task form receives defined flags, `TaskDetailFlagSuggestionTests` verifies edit-state loading and selection, and `TaskFormFlagSuggestionPresentationTests` keeps the suggestion list bounded.
