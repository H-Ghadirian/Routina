# 0021 — Place shared actions before conditional actions

Date: 2026-07-25

## Symptom

The Mac task-detail `Done` button was leftmost for one-time tasks but moved to the right of `Pause` or `Resume` for repeating tasks.

## Root Cause

The action cluster declared the repeating-task-only Pause/Resume branch before the completion button. SwiftUI preserved declaration order, so enabling that conditional action changed the completion button's position.

## Fix

The shared completion button is now declared first, followed by task-type-specific secondary actions.

## Prevention Rule

When an action must keep a stable position across presentation variants, declare that shared action before conditional sibling actions instead of relying on conditions to preserve visual order.

## Regression Safeguard

`PerformanceRegressionTests.testMacTaskDetailCompletionActionPrecedesTaskSpecificActions` verifies that the completion action remains before both Pause/Resume and Cancel in the Mac task-detail action cluster.
