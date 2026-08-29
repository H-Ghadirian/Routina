# 0263 — Refresh lazy row chrome at the owner boundary

Date: 2026-08-29

## Symptom

After selecting `tax declaration` in the Mac Task Ladder, its details opened on
the right while the previously selected `read about testestron` row kept the blue
selection tint.

## Root Cause

The earlier safeguard in [0253](0253-capture-observable-selection-before-lazy-row-construction.md)
moved selection reads out of individual lazy rows, but stopped inside the
`rankingList` builder. That builder was still retained beneath `HSplitView`, and
the realized row subtree kept its existing visual identity. SwiftUI could update
the Task Details sibling without replacing the old row chrome, so feature state
remained single-selection while the previous background survived.

## Fix

The Task Ladder now observes task and group selection directly in the owning
view's `body`, before constructing the split view, and passes one namespaced
selected-node value into the ranking list. Each row also has an inner chrome
identity made from its namespaced node and selected state. Changing selection
therefore replaces the old and new row chrome subtrees while the outer lazy item
keeps its stable task ID and scroll target.

## Prevention Rule

Observe state that controls lazy-child chrome at the owning view-body boundary,
not only inside a descendant builder. If a proven SwiftUI reuse defect requires
identity invalidation, apply the smallest state-derived identity to the affected
row subtree; never change the scrolling container's identity for ordinary
selection updates.

## Regression Safeguard

`TaskRankingPresentationTests.taskLadderObservesSelectionAtBodyAndRefreshesOnlyChangedRowChrome`
guards the observation and row-identity boundaries.
`taskLadderRowSelectionIdentityChangesOnlyForOldAndNewSelection` verifies that a
selection move invalidates exactly the previous and new rows while unrelated row
identities remain stable. The Mac Task Ladder placement scenario covers agreement
between the selected detail and the single tinted row after lazy reuse.
