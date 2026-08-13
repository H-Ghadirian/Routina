# 0160 — Keep task-time corrections wired to their editing state

Date: 2026-08-13

## Symptom

On macOS, an accidental task-level actual-time entry could only be increased from the visible Time section. Edit Task accepted a different Actual value but left Save disabled.

## Root Cause

The Mac Task Detail action expanded the additive time-entry control instead of presenting the existing task-total editing state. Separately, the shared edit change detector omitted `actualDurationMinutes`, so the form did not recognize the correction as a change.

## Fix

Mac Task Details now exposes `Edit total` beside `Add` and presents the task-total editor, which can replace or clear the value. The edit change request and detector now include actual time spent.

## Prevention Rule

Every persisted form field must participate in the form's dirty-state comparison. When a platform has shared editing state, its visible action must present that state rather than routing to a similarly named but semantically different additive control.

## Regression Safeguard

`TaskDetailEditSaveTests` verifies an actual-time-only edit enables Save. `TaskDetailSharedViewSupportTests` verifies the Mac task-total editor sheet, save action, and header affordance remain connected.
