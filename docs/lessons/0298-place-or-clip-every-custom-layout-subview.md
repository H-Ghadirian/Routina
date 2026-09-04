# 0298 — Place or clip every custom-layout subview

Date: 2026-09-04

## Symptom

A compact Mac task row showed several overflow pills such as `+4 more` and
`+2 more` on top of its Tag and Flag chips instead of showing one fitted result.

## Root Cause

The custom layout received one overflow candidate for every possible hidden
count but placed only the selected candidate. SwiftUI still drew the unplaced
layout subviews at their default origin, so the candidate views overlapped.

## Fix

The layout now explicitly places every unused candidate outside its bounds and
clips drawing to those bounds. The compact label group exposes one combined
accessibility label so offscreen candidates cannot create duplicate VoiceOver
content.

## Prevention Rule

A custom SwiftUI `Layout` that conditionally selects among supplied subviews must
still explicitly place or suppress every unselected subview. Clip the layout when
off-bounds placement is the suppression mechanism, and define accessibility at
the selected container boundary.

## Regression Safeguard

`HomeMacTaskRowMetadataLayoutSourceTests.unifiedSecondaryLabelRowRendersTagsFlagsAndGoals`
requires explicit unused-subview placement, clipping, and combined accessibility.
The Mac task-row regression scenario requires exactly one overflow summary with
no candidate overlap.

Related decision: [0731 — Let Mac Task-Row Details Wrap](../decisions/0731-let-mac-task-row-details-wrap.md).
