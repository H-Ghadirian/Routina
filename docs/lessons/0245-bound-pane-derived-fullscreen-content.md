# 0245 — Bound pane-derived fullscreen content

Date: 2026-08-24

## Symptom

Expanding Mac Planner Filters fullscreen stretched pane-oriented segmented
controls and cards across the full detail width.

## Root Cause

Fullscreen reused the 420-point companion-pane content under an unconstrained
infinite-width proposal without a readable content boundary.

## Fix

Fullscreen now centers filter content within an 840-point maximum while the
companion pane remains 420 points wide.

## Prevention Rule

When a narrow companion surface expands fullscreen, give its content an
explicit readable maximum or an intentional adaptive layout before proposing
the full window width.

## Regression Safeguard

`Tests/macOS/PerformanceRegressionTests.swift` requires the fullscreen maximum
alongside the established companion-pane width.
