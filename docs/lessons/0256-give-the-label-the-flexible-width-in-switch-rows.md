# 0256 — Give the label the flexible width in switch rows

Date: 2026-08-27

## Symptom

Task List, Timeline, and Calendar Appearance switches drifted horizontally in
the wide Mac filter view. Short labels sat near the center while longer labels
pushed their switches farther right, so the form did not scan as columns.

## Root Cause

Each native SwiftUI `Toggle` received an infinite-width outer frame, but its
label retained its intrinsic width. Expanding the control shell did not tell
the toggle's internal label-and-switch layout which element should absorb the
extra space.

## Fix

All three Appearance screens now use one shared native toggle row. Its
title-and-subtitle label accepts the flexible width and stays leading-aligned,
which places every switch in one trailing column while keeping the expanded
label surface clickable.

## Prevention Rule

For an aligned label/control row, assign flexible width to the label column,
not only to the outer control. Verify both the visual alignment and the hit
target whenever a compact native control is expanded into a desktop form row.

## Regression Safeguard

`Tests/macOS/PerformanceRegressionTests.swift` requires the shared Appearance
row to keep a native switch, a full-width leading label, and an expanded hit
shape, and requires Task List, Timeline, and Calendar Appearance screens to use
that row.
