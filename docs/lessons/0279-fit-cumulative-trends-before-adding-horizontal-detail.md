# 0279 — Fit cumulative trends before adding horizontal detail

Date: 2026-08-31

## Symptom

Cumulative Focus showed a correct nonzero total and detail card while its plot
looked empty in a year range whose Focus activity was near the period's end.

## Root Cause

The overview line inherited the daily bar chart's 2,600-point horizontal canvas.
An initial viewport could show only the early zero baseline, leaving the actual
rise outside the visible region and making valid data look missing.

## Fix

The cumulative trend now fits the complete selected period into its viewport,
samples a compact axis-label set, uses an explicit plot height, and marks its
latest point. Detailed daily bars retain their independent overflow behavior.

## Prevention Rule

Choose chart overflow from the analytical question. Distribution charts may
need scrollable per-bucket detail; overview trends must first show the complete
shape and should not rely on an undiscovered initial scroll position to reveal
nonzero evidence.

## Regression Safeguard

`StatsFeatureDerivedStateSupportTests` verifies that the cumulative section does
not use horizontal scrolling, retains a bounded height and endpoint, and uses
its compact whole-range axis sampler. The Focus-chart scenario records the
visible whole-period contract.

Related decision: [0708 — Fit Overview Charts and Structure Compact Stats Facts](../decisions/0708-fit-overview-charts-and-structure-compact-stats-facts.md).
