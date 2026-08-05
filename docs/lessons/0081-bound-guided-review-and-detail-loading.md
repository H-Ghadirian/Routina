# 0081 — Bound guided review and detail loading

Date: 2026-08-05

## Symptom

On iOS, guided Pressure, Importance, or Urgency review could hitch with more
than 250 tasks, especially when the user repeatedly opened Task Details and
returned to the next card.

## Root Cause

The procedures eagerly built presentation data for every eligible card even
though only one card was visible. Task Details then refetched every task,
place, goal, and historical log whenever Home selected the same task again.

## Fix

Guided procedures now store ordered task IDs and only the current card's
presentation. Save and Skip fetch the next task directly. Home supplies its
loaded display and edit context to Task Details, which skips the redundant
global edit-context fetch while retaining focused logs and attachments loads.

## Prevention Rule

For one-at-a-time procedures, retain compact candidate identity and derive
presentation for the visible item only. A detail route backed by an existing
Home snapshot must reuse that snapshot rather than repeating whole-store work
on every navigation round trip.

## Regression Safeguard

`MissingPressureDataFeatureTests`, `MissingTaskMetadataFeatureTests`, and
`HomeFeatureSelectionRouterTests` verify lazy candidate state and preloaded
detail context. `RoutinaUIPerformanceTests` seeds 300 review tasks and 9,000
logs before measuring review-to-detail round trips. The expected behavior is
also recorded in `docs/scenarios/README.md`.
