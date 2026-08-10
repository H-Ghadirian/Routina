# 0131 — Let compact iOS tag chips wrap before truncating

Date: 2026-08-10

## Symptom

iOS Add Task and Edit Task abbreviated selected, related, and suggested tag
labels even when the Tags section had enough unused horizontal space to show
them completely.

## Root Cause

The compact Tags section used a narrow adaptive grid. SwiftUI split the row
into equal cells before measuring the chips, so variable-length labels were
ellipsized inside those cells.

## Fix

The Tags section now uses the shared intrinsic-width flow layout. Each chip
keeps its complete label and moves to a new row only when it no longer fits.

## Prevention Rule

Use intrinsic-width wrapping layouts for variable-length metadata chips in
compact forms. Grid cells are appropriate only when equal-width controls are
intentional.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.tagsKeepSuggestionsBoundedAndBrowseTheFullCatalogInASearchablePicker`
asserts that the Tags section uses `HomeFilterFlowLayout` instead of the narrow
adaptive grid. The iOS Task Form Tags scenario records the full-label behavior.
