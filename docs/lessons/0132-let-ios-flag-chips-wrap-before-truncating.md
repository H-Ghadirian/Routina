# 0132 — Let iOS Flag chips wrap before truncating

Date: 2026-08-11

## Symptom

iOS Add Task, Edit Task, and Task Details shortened Flag names even when
unused row width could display the complete labels.

## Root Cause

The Flag sections used adaptive grids with narrow, equal-width cells. SwiftUI
allocated each chip to its cell before measuring its variable-length label.

## Fix

The iOS task-form and Task Detail Flag sections now use the shared
intrinsic-width flow layout. Flag chips retain their full labels and wrap only
when the next chip no longer fits on the row.

## Prevention Rule

Use an intrinsic-width wrapping layout for variable-length metadata chips in
iOS task surfaces. Reserve adaptive grids for deliberately equal-width
controls.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.flagsUseIntrinsicWidthBeforeWrappingInTaskForms`
and `TaskDetailFlagPresentationTests.assignedFlagsUseIntrinsicWidthBeforeWrapping`
assert that Flag sections use `HomeFilterFlowLayout`. The Task Detail Flags
scenario covers the shared behavior.
