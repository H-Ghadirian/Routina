# 0135 — Gate Home Goal filters with feature availability

Date: 2026-08-11

## Symptom

The iOS Home Filters sheet exposed its Goal option while the Settings `Show
Goals tab` toggle was off.

## Root Cause

Home Filters rendered its Goal section unconditionally, while the owning Home
view did not read the Goals feature-availability preference or pass it into
the filter-sheet configuration.

## Fix

Home now reads `appSettingGoalsTabEnabled`, carries the value through
`HomeFiltersSheetConfiguration`, and renders the Goal filter section only when
Goals is enabled.

## Prevention Rule

Every optional feature surface must receive and apply the same availability
gate as its navigation and reporting entry points; do not assume another screen
has already hidden it.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.homeFiltersHideGoalsWhenTheGoalsFeatureIsDisabled`
checks the preference, configuration plumbing, and conditional Goal section.
