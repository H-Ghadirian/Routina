# 0278 — Gate Timeline membership with the Sleep capability

Date: 2026-08-31

## Symptom

Sleep was absent from Timeline's type controls when its default-off experiment
was unavailable, but persisted Sleep sessions still appeared under `All`.

## Root Cause

The filter-choice and stale-selection paths used the effective Away-plus-Sleep
capability, while the Timeline data feed passed the raw persisted Sleep
collection. Availability controlled how rows could be filtered but not whether
those rows belonged to the presentation.

## Fix

iOS and both Mac Timeline owners now pass Sleep sessions only when both required
settings are enabled. Setting changes invalidate membership and normalize a
stale Sleep filter without deleting the stored records.

## Prevention Rule

For every optional Timeline record type, derive filter choices, row membership,
empty-state evidence, and setting-change invalidation from the same effective
capability. A hidden filter is not sufficient to hide records under `All`.

## Regression Safeguard

`IOSNewTabActionAvailabilityTests` and macOS `PerformanceRegressionTests`
verify the gated data feeds and setting observers. The Timeline feature-gate
scenario covers preserved Sleep records on both platforms.

Related decision: [0707 — Gate Disabled Sleep at Timeline Presentation Boundaries](../decisions/0707-gate-disabled-sleep-at-timeline-presentation-boundaries.md).
