# 0253 — Capture observable selection before lazy row construction

Date: 2026-08-26

## Symptom

Selecting a Mac Task Ladder container group could leave several unrelated group
rows tinted as though they were selected. Which rows looked selected could change
as the lazy list was reused or scrolled, even though the details pane held only
one selected group.

## Root Cause

Each lazy row read the observable store's task and group selection directly while
SwiftUI realized that row. Those reads happened below the stable list-building
boundary, so a later selection change did not reliably invalidate every already
realized sibling row. The feature state remained single-selection, but stale row
chrome could survive in the lazy view tree.

## Fix

The Task Ladder list now captures task selection, group selection, and search
highlight membership before constructing the `LazyVStack`. It converts the two
selection fields into one namespaced `TaskLadderNodeID` and passes immutable
selection/highlight inputs into each row. The row also exposes its selected state
to accessibility.

## Prevention Rule

Read observable state that controls per-row chrome before entering a lazy builder,
then pass immutable values into the rows. Namespace selection identity when one
lazy surface contains several semantic row kinds.

## Regression Safeguard

`TaskRankingPresentationTests.taskLadderCapturesSelectionBeforeBuildingLazyRows`
guards the observation boundary and namespaced row comparison. The Mac Task
Ladder placement scenario requires that selecting another row clears the previous
tint even after lazy scrolling and reuse.
