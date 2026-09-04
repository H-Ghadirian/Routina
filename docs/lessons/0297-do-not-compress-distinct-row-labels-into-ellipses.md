# 0297 — Do not compress distinct row labels into ellipses

Date: 2026-09-04

## Symptom

A Mac task row with Tags and Flags enabled showed several pills containing only
`#…` or a Flag icon plus an ellipsis, so the supposedly visible fields could not
be identified.

## Root Cause

Every secondary label shared one horizontally constrained stack with a trailing
status badge. The chips allowed horizontal compression and the container enforced
one line, so SwiftUI satisfied the width proposal by truncating each distinct
label rather than choosing an explicit overflow presentation.

## Fix

Task rows now keep individual chips at their readable intrinsic width. Compact
rows select the largest fitting prefix and summarize omitted labels with a
`+N more` chip whose hover and accessibility text names them. The new independent
`Multiline Details` appearance choice flows all enabled labels and grows the row
to their required height.

## Prevention Rule

When a setting says a repeated metadata field is visible, preserve each item's
recognizable identity. If the row cannot fit every item, use an explicit count or
an opt-in wrapping layout; never let layout compression turn several distinct
values into identical ellipses.

## Regression Safeguard

`HomeTaskListFilteringTests.taskRowVisibilityRoundTripsIndependentMultilineChoices`
protects the independent persisted layout tokens.
`HomeMacTaskRowMetadataLayoutSourceTests` protects the adaptive flow, compact
fitting candidates, overflow summary, and Appearance wiring.
`SettingsFeatureTests.taskRowMultilineDetailsChanged_persistsSelection` verifies
that the new choice reaches durable preferences.

Related decision: [0731 — Let Mac Task-Row Details Wrap](../decisions/0731-let-mac-task-row-details-wrap.md).
