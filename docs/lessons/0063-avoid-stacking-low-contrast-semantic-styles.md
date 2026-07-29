# 0063 — Avoid stacking low-contrast semantic styles

Date: 2026-07-29

## Symptom

The task count beside the iOS Home `Daily Routines` section title was nearly
invisible in dark mode.

## Root Cause

The count used a tertiary foreground inside a native List section header.
Because the section header already presents content with a subdued treatment,
the additional tertiary style compounded the contrast reduction.

## Fix

Collapsible iOS Home section counts now use the secondary semantic foreground,
remaining visually subordinate while matching the readable contrast of their
header context.

## Prevention Rule

Account for the contrast treatment supplied by the parent container before
adding another low-emphasis semantic style. Small metadata inside an already
subdued system header should not use tertiary contrast when it must remain
legible.

## Regression Safeguard

`HomeIOSSectionHeaderContrastTests` isolates the collapsible section-header
source and verifies that its task count uses secondary rather than tertiary
foreground contrast. The behavior is also recorded in
`docs/scenarios/README.md`.
