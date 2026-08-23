# 0229 — Keep retired task types out of active guidance

Date: 2026-08-23

## Symptom

Guidance told a person to configure a Tracking task or leave `Track this routine` disabled even though Routina exposes neither a Tracking task type nor that control.

## Root Cause

Decision 0436 retired Tracking from the product, but the decision index retained an older consolidated description of Tracking forms, sections, and eligibility. Presentation code also relied on scattered `.record` special cases, while local help did not answer time-based eligibility or retired-Tracking questions explicitly.

## Fix

The active decision summary and current-behavior guidance now describe only the real `One-time` and `Repeating` choices. User-facing task-kind text is centralized through `RoutineTaskType.userFacingTitle`, time-based APIs use cadence terminology, and the help catalog explains exact time-based eligibility while stating that Tracking is not a type, Flag, control, or requirement.

## Prevention Rule

When a product concept is retired, remove it from every active summary and help surface, then centralize compatibility-to-presentation mapping so persisted legacy names cannot leak through raw values or ad hoc copy. Historical decision records may retain the old term only when their superseding status is clear.

## Regression Safeguard

`TaskFormPresentationTests` verifies that internal record rows have only the user-facing Routine title. `RoutinaHelpCatalogTests` verifies that both time-based and Tracking questions resolve to current repeating-task guidance. `TaskRankingPresentationTests` verifies that legacy record rows remain ineligible for time-based values, and the retired-task scenario forbids a Tracking Flag or `Track this routine` control.
