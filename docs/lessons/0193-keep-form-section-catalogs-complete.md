# 0193 — Keep form section catalogs complete

Date: 2026-08-18

## Symptom

`Thinking needed` appeared in Task Details but did not appear in macOS Edit Task, even though the edit form had a working Thinking-needed card and persisted the field.

## Root Cause

The macOS `FormSection` enum and form renderer included `.thinkingNeeded`, and populated-section derivation could mark it visible, but `FormSection.taskFormSections` omitted it from the available section catalog. Progressive form visibility can only reveal sections that exist in the available catalog, so Edit Task never rendered the card.

## Fix

Add `.thinkingNeeded` to the macOS task-form section catalog immediately after `.temporalWeight` and before `.estimation`, matching the intended priority-context order.

## Prevention Rule

When adding or restoring a form card, update the enum, renderer switch, populated-section derivation, and the available-section catalog together. A section that is not in the catalog is unreachable regardless of bindings or populated-state logic.

## Regression Safeguard

`FormSectionTests.taskFormSectionsIncludeIdentityAndDangerZoneWhenRequested` now asserts that macOS task forms include `Thinking needed` in the expected order.
