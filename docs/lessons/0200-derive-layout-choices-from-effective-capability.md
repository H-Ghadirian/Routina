# 0200 — Derive layout choices from effective capability

Date: 2026-08-18

## Symptom

The Mac Planner displayed a `Week` range choice at a width where selecting it could only leave the calendar in `3 Days`. The header also retained expanded segmented controls and a textual `Go to date` button after the layout needed compact controls.

## Root Cause

Header fit, adaptive range eligibility, rendered day-column width, and date-button compaction were decided by separate thresholds. The range calculation used a hard-coded width larger than the renderer's actual minimum, and the header always offered all range cases even when the calendar had already constrained the effective range.

## Fix

Range eligibility now uses the renderer's shared minimum day width, and the Planner publishes the currently supported range modes. The header lists only those modes and switches all of its segmented choices to current-value menus when the regular row cannot fit or the calendar has constrained the range catalog. That same compact state makes `Go to date` icon-only.

## Prevention Rule

Never present a layout-dependent choice unless the current layout can honor it. Derive both rendering and option availability from one capability calculation, and make related compact fallbacks consume one shared presentation state.

## Regression Safeguard

`DayPlanPlannerStateTests` covers the shared column-width boundary, supported range catalog, compact-header decision, and preferred-range restoration. `Tests/macOS/PerformanceRegressionTests.swift` guards the compact menu and icon-only source contract. The scenarios are recorded in `docs/scenarios/planner-header-keeps-only-actionable-range-choices.md` and `docs/scenarios/go-to-date-button-becomes-icon-only-when-header-is-tight.md`.

This extends [0195](0195-show-icon-only-before-date-label-truncation.md) and [0197](0197-measure-the-active-header-variant.md): measuring the active variant remains necessary, but all related controls must also share the resulting compact state.
