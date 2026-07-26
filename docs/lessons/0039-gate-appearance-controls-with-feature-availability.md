# 0039 — Gate appearance controls with feature availability

Date: 2026-07-26

## Symptom

The Mac Home filter companion pane showed a `Places` task-row appearance toggle even when the Places beta experiment was off.

## Root Cause

The companion pane gated the place filter section, but built its separate task-row appearance field list from every supported row field. Feature availability was not part of that second presentation model.

## Fix

The Mac task-row appearance field list now receives Places availability independently and excludes the place field while the beta experiment is off.

## Prevention Rule

When a feature flag hides a product concept, gate every presentation model that can expose it, including configuration and appearance controls. Do not assume gating the primary feature section also gates adjacent customization surfaces.

## Regression Safeguard

`HomeTaskListFilteringTests.appearanceFieldsRespectFeatureAvailability` verifies that the appearance field list excludes Places and Goals when their beta surfaces are unavailable and restores them when enabled.
