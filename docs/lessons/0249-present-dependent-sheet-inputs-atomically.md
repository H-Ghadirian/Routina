# 0249 — Present dependent sheet inputs atomically

Date: 2026-08-26

## Symptom

The Mac Focus sheet could show tagged task rows while omitting the entire tag
filter strip.

## Root Cause

The sheet presentation used one Boolean to open while its tasks, available-tag
catalog, and recalled defaults lived in separate view state. SwiftUI could
evaluate the Boolean-backed sheet with inputs from different parent-view
updates, so the tag catalog could still be empty while the task rows already
used the current tagged tasks.

## Fix

The Focus entry point now builds one identifiable presentation value containing
the eligible tasks, their recency-ordered tag catalog, and the recalled Focus
defaults. An item-backed sheet receives that exact value and renders all three
dependent inputs together.

## Prevention Rule

When a transient surface depends on several values derived from one source,
build one identifiable presentation payload and present that item. Do not open
the surface with a separate Boolean while independently mutating its required
inputs.

## Regression Safeguard

`PerformanceRegressionTests.testMacFocusPickerPresentationSnapshotsTasksTagsAndDefaultsTogether`
verifies that a tagged task produces the same payload's tag catalog and recalled
defaults. `testMacFocusStartUsesOneRecallingSheet` verifies item-backed sheet
presentation and rejects the former separate available-tag state. The Mac Focus
scenario requires tagged rows and their filters to appear together.
