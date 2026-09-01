# 0271 — Gate preserved data at every feature presentation boundary

Date: 2026-08-29

## Symptom

With `Show Goals tab` off, an iOS Home task row and Task Details still displayed
the task's linked Goal even though Goal navigation, editing, and filtering were
hidden.

## Root Cause

The read-only presenters treated persisted Goal links as sufficient reason to
render. The Home row checked only its saved Task Row Appearance field, while
Task Details checked only whether Goal summaries existed. Neither presentation
boundary also checked the Goals feature-availability setting.

## Fix

The Home list owner now combines Goals availability with the saved row field
before asking a row to present linked Goals. Task Details applies the same
availability setting before rendering its Goal summary. Existing links and the
saved Task Row Appearance choice remain stored so enabling Goals restores the
presentation.

## Prevention Rule

Every optional feature gate must cover read-only presentations as well as
navigation, creation, editing, filtering, and reporting. Preserved data is not
evidence that its feature is currently available.

## Regression Safeguard

The iOS Goal-gate scenario requires Home rows and Task Details to hide persisted
Goal links while the feature is off. `TaskFormIOSLayoutRegressionTests` verifies
that both presentation paths consume the Goals availability setting.

Related decision: [0538 — Gate Add Task Goals with the Feature Setting](../decisions/0538-gate-add-task-goals-with-feature-setting.md).
