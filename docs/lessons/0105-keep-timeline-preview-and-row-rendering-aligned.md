# 0105 — Keep Timeline preview and row rendering aligned

Date: 2026-08-08

## Symptom

The iOS Appearance Timeline Row preview expanded into a tall empty card with a vertically stretched type badge, while the Timeline list itself used compact rows and did not render the enabled row-number field.

## Root Cause

The preview used flexible Liquid Glass surfaces inside a scrolling Settings list instead of the Timeline row's fixed fills. Separately, iOS had no cached display-order row-number lookup even though the Appearance preference exposed that field.

## Fix

The preview now uses the same compact fixed icon, pill, subtitle, and type treatment as Timeline. TimelineFeature derives row-number lookup data from its grouped presentation snapshot, and iOS rows consume that cache.

## Prevention Rule

An Appearance preview must exercise every enabled field using the same layout primitives as its production row; positional row data belongs in the immutable presentation snapshot, never in a scrolling row builder.

## Regression Safeguard

`TimelineFeatureTests.setData_groupsEntriesAndCollectsAvailableTags`, `IOSScrollingPerformanceRegressionTests`, and `SettingsTimelineRowPreviewTests` verify display-order numbering, cached consumption, and the preview's compact fixed surfaces. The cross-surface contract is documented in `docs/scenarios/README.md`.
