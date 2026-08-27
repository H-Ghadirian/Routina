# 0255 — Do not carry compact row caps into wide layouts

Date: 2026-08-27

## Symptom

Mac fullscreen Filters showed segmented controls across two or three rows even
when every option could fit comfortably on one line.

## Root Cause

The same filter views served both the 420-point companion pane and the bounded
840-point fullscreen surface, but their `maximumSegmentsPerRow` values were
fixed for the narrow pane rather than derived from the width actually offered
to the controls.

## Fix

The filter container now supplies a width-derived compact or wide layout
capability. Compact layouts use menu pickers for single-choice controls that
would otherwise need multiple segment rows; wide layouts use full-width,
single-row segments. The same work expands suitable Timeline segments, labels
the task status control, and aligns switch rows to the card's trailing edge.

## Prevention Rule

When one SwiftUI surface is reused at materially different widths, treat row
caps, wrapping, filling, and alignment as width-dependent layout decisions.
Do not encode the narrow presentation's line breaks as unconditional control
configuration.

## Regression Safeguard

`Tests/macOS/PerformanceRegressionTests.swift` verifies the 420-point compact
picker and 840-point wide segment policies and requires the affected filter
controls to use the shared adaptive choice control.
