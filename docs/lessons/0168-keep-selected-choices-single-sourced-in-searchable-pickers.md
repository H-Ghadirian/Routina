# 0168 — Keep selected choices single-sourced in searchable pickers

Date: 2026-08-16

## Symptom

iOS Filter Tags showed active tags in a dedicated `Selected tags` section and
then repeated the same tags in the searchable Show or Hide catalog. Selection
felt denser and less predictable than the Add Task tag picker.

## Root Cause

The filter picker added a second selected-row presentation to keep active rules
visible, but its catalog continued to contain those same selected models. The
visibility requirement and the selection interaction were implemented as two
separate lists instead of two orderings of one list.

## Fix

Filter Tags now builds one catalog, pins active Hidden and Included rules at its
top, and renders every tag once. Selected rows remove their existing rule;
unselected rows add the current Show or Hide rule. Search narrows only the
unselected portion so active rules remain visible.

## Prevention Rule

When a searchable picker must keep selected choices visible, derive one row
model per semantic choice and reorder or partition that single collection. Do
not render a second selected section unless selected choices are explicitly
removed from the searchable catalog.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.filterTagsUseTheTaskTagPickerSelectionPatternWithoutDuplicateRows`
guards the one-list plus/check structure. The iOS scrolling regression test
guards the cached selected-rule presentation, and the Filter Tags regression
scenario protects the expected interaction.
