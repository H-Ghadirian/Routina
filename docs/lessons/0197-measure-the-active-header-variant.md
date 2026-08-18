# 0197 — Measure the active header variant

Date: 2026-08-18

## Symptom

The macOS Planner still displayed an ellipsized `Go to date` label while Day / 3 Days / Week remained visible, despite a width-based icon-only fallback.

## Root Cause

The fallback compared available width only with the range-hidden regular row. That row fit, so the date button stayed textual even though the active row still included the range picker and overflowed. The label itself also allowed scaling and middle truncation, masking the incorrect fit decision.

## Fix

The header now measures three stable variants: the full row with compact date icon, the full row with intrinsic date label, and the range-hidden row with intrinsic date label. The compact full row decides whether the range picker can remain; the matching active regular row decides whether Go to date must become icon-only. The regular label uses intrinsic horizontal size and no truncation fallback.

## Prevention Rule

Adaptive layout decisions must compare the available width with the exact control variant that will remain visible. Measure compact and regular alternatives independently to avoid circular state and never use a collapsed variant to predict an expanded row.

## Regression Safeguard

`DayPlanPlannerStateTests.datePickerFitUsesFullRowWhileRangePickerRemainsVisible` covers the reported layout combination, while `datePickerButtonSwitchesToIconOnlyBeforeRegularDateTextOverflows` protects the fit boundary. The behavior is captured in `docs/scenarios/go-to-date-button-becomes-icon-only-when-header-is-tight.md`.
