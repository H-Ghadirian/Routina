# 0180 — Match fallback overflow glyph weight to toolbar icons

Date: 2026-08-16

## Symptom

The iOS Task Detail overflow menu worked, but its vertical dots looked much
smaller and lighter than the neighboring Edit symbol.

## Root Cause

The overflow trigger used the reliable explicit `⋮` fallback established after
the vertical SF Symbol failed to render, but it inherited the toolbar's default
text styling. A Unicode text glyph does not automatically match the optical size
or weight of an adjacent SF Symbol.

## Fix

The existing `⋮` fallback now has an explicit 22-point bold rounded font and a
24-point label frame, preserving its reliable rendering while matching the
neighboring toolbar icon more closely.

## Prevention Rule

When a toolbar icon must use a text-glyph fallback, specify and compare its
optical size, weight, alignment, and interactive label area against adjacent SF
Symbols; reliable rendering alone is not enough.

## Regression Safeguard

`TaskDetailPlatformActionParityTests.iosTaskDetailsGroupMaintenanceActionsInNavigationOverflow`
requires the explicit vertical-dot glyph, its bold 22-point styling, its
24-point frame, and its content shape. The iOS Task Detail maintenance-action
scenario records the expected visual weight beside Edit.

Related lesson: [0174 — Apply proven overflow glyphs across platforms](0174-apply-proven-overflow-glyphs-across-platforms.md).
