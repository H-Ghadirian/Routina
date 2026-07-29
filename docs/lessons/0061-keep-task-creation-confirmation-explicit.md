# 0061 — Keep task-creation confirmation explicit

Date: 2026-07-29

## Symptom

The Mac full Add Task form disappeared after Save without an explicit success
message, while the Quick Add confirmation left a visibly large empty area
after its close button.

## Root Cause

Full-form creation treated post-save navigation as sufficient feedback and did
not model a success confirmation. In the toast, a fixed-width wrapper expanded
an ideal-width row that had no flexible spacer, leaving the extra width after
the trailing controls.

## Fix

Successful full-form creation now records explicit confirmation state and
presents the shared created-task toast after routing to the new task's details.
The toast inserts flexible width before its optional action and close control,
anchoring those controls to the normal trailing inset.

## Prevention Rule

Represent successful transient workflows with explicit success state, and in
fixed-width horizontal feedback panels place flexible space before trailing
actions rather than allowing unused width to collect after them.

## Regression Safeguard

`HomeFeatureTests` verifies that successful creation produces dismissible
confirmation state. `PerformanceRegressionTests` protects the toast's
message/spacer/action ordering.
