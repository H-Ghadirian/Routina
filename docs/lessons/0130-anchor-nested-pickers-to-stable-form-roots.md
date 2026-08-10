# 0130 — Anchor nested pickers to stable form roots

Date: 2026-08-10

## Symptom

Opening `Browse all tags` from an iOS Edit Task form could immediately dismiss
both the tag picker and the edit sheet, returning the person to Task Details.

## Root Cause

The picker state and sheet modifier lived on the Tags section inside the form's
dynamic section collection. SwiftUI could recreate that transient presentation
host while presenting the nested sheet, invalidating the local binding and
dismissing the edit stack.

## Fix

The stable `TaskFormContent` root now owns the tag-picker state and presents
the picker. The Tags section receives only a binding used to request that
presentation.

## Prevention Rule

Present nested sheets from a stable form root, not from a conditional or
collection-backed section that can be recreated during a presentation change.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.tagPickerPresentationIsOwnedByTheStableFormRoot`
checks that the form root owns the sheet state and the Tags section only holds
its binding. The iOS Tag Browser scenario records the expected return to the
still-open task form.
