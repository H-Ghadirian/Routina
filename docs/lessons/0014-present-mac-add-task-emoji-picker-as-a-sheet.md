# 0014 — Present the Mac Add Task emoji picker as a sheet

Date: 2026-07-24

## Symptom

Clicking the plus badge on the emoji control in the Identity section of Mac Add Task crashed the app instead of opening the chooser.

## Root Cause

The Add Task emoji chooser used a SwiftUI popover from inside the progressively composed task form. That presentation path was unstable on macOS. The equivalent task-detail chooser already used a sheet and did not have the crash.

## Fix

Mac Add Task now presents the emoji chooser as a sheet, matching the stable task-detail presentation path.

## Prevention Rule

Present the shared Mac emoji chooser as a sheet from task forms. Do not reintroduce the form-local popover presentation path without an interaction-level regression check.

## Regression Safeguard

`PerformanceRegressionTests.testMacAddTaskEmojiChooserUsesStableSheetPresentation` verifies that the Mac Add Task platform modifier uses sheet presentation and does not regress to the crashing popover path.
