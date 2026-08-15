# 0167 — Name each iOS filter choice once

Date: 2026-08-16

## Symptom

The iOS Filters sheet repeated names such as `Pressure`, `Thinking needed`, and
`Media` in a section heading immediately above a row with the same name. After
opening Media, the detail sheet repeated `Media` below its navigation title.

## Root Cause

The shared compact filter entry wrapped every single row in its own named
`Section`, even when the row label already identified the choice. Inline
pickers also kept their visible label when the detail sheet's navigation title
already supplied the same context.

## Fix

Home, Stats, and Timeline now present filter entries as direct rows in one
compact list group. Dedicated picker sheets hide redundant inline picker labels
while keeping semantic labels available to assistive technologies.

## Prevention Rule

Name a filter concept once at each visible navigation level: use the row label
in the primary list and the navigation title in its detail sheet. Do not add a
single-row section title or visible inline-picker label that only echoes that
context.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.iosFilterListsDoNotRepeatNavigationOrEntryTitles`
guards the shared row structure and hidden Media picker label, and the iOS
filter-title regression scenario covers Home, Stats, and Timeline.
