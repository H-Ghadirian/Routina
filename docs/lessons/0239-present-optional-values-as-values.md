# 0239 — Present optional values as values

Date: 2026-08-24

## Symptom

The task form presented Time estimate, Actual time, and Story points as `Set …`
switches beside a `Show focus timer` switch. People could not readily tell
which controls stored values, which enabled a capability, or how the four
concepts differed.

## Root Cause

The presentation mapped optional-value presence directly to a Boolean switch.
That implementation shortcut made creating or clearing a value look identical
to enabling or disabling Focus, and the aggregate `Estimation` title hid the
broader effort relationship.

## Fix

The cross-platform form now calls the group `Effort`. Estimate, Actual time, and
Story points use semantic value rows with explicit Set/Log and Remove/Clear
actions plus their existing inline editors. Focus alone remains a toggle. Shared
presentation vocabulary and model mutations keep both platforms aligned, and
Actual time starts independently instead of borrowing the Estimate.

## Prevention Rule

Use a switch only for a durable Boolean choice. Present optional numeric or text
data as a value with explicit create, edit, and clear actions, and name grouped
but independent fields by their shared concept rather than one member's data
type.

## Regression Safeguard

`TaskFormPresentationTests` verifies shared vocabulary, action titles, defaults,
and field independence. `TaskFormIOSLayoutRegressionTests` and
`TaskFormMacLayoutRegressionTests` verify that the three value switches do not
return and that Focus remains the sole toggle.

See [Decision 0653](../decisions/0653-present-effort-values-as-values-not-feature-switches.md)
and [Regression Scenarios](../scenarios/README.md#task-effort-editing-distinguishes-values-from-capabilities).
