# 0109 — Wrap Five-Option iOS Filter Segments

Date: 2026-08-08

## Symptom

The iOS Home filter sheet compressed the five Pressure and Thinking needed choices into one equal-width row, truncating `Medium` and making both controls look crowded.

## Root Cause

The shared segmented-control default renders every option in one horizontal row when no row limit is specified. Five labels did not fit within the filter sheet's available width.

## Fix

Pressure and Thinking needed now use the segmented control's three-options-per-row layout with compact padding, so the filters render as a readable three-and-two grid.

## Prevention Rule

For iOS filter segments with five human-readable values, constrain the row to at most three items instead of relying on one-line equal-width compression.

## Regression Safeguard

`HomeIOSTaskTypeSegmentLayoutTests.pressureAndThinkingFiltersWrapFiveValuesWithoutTruncatingMedium` checks that both filters keep the three-per-row, full-width configuration.
