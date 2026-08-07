# 0098 — Keep direct task linkers on the full preloaded catalog

Date: 2026-08-07

## Symptom

The macOS Task Details `Link a Task` picker reported that all tasks were already linked, even when the person had many unrelated tasks available.

## Root Cause

Home preloads two relationship candidate collections: a lightweight list of relationship neighbors for Task Details presentation and the full catalog for editing. The direct macOS linker used the lightweight neighbor list, then removed its already-linked entries, leaving no candidates.

## Fix

The direct macOS linker and its reducer action now use the full preloaded link catalog while Task Details continues to use the lightweight neighbor list for ordinary relationship presentation.

## Prevention Rule

When an action needs to choose a new relationship target, derive its candidates and validation from the full editable or linkable catalog, never from the display-only collection of existing relationship neighbors.

## Regression Safeguard

`HomeFeatureSelectionRouterTests` verifies that the linkable catalog contains unrelated tasks from Home's snapshot. `TaskDetailEditSaveTests` verifies that the direct action accepts and persists a task present only in that full catalog. The `Mac Linked-Task Actions Stay Distinct` scenario records the picker behavior.
