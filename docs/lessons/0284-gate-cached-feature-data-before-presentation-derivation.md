# 0284 — Gate cached feature data before presentation derivation

Date: 2026-09-01

## Symptom

Mac Planner and Timeline displayed preserved standalone Events while the Events
experiment and its visible filter control were off. This made release screenshot
content advertise a feature that production users cannot create or enable.

## Root Cause

The feature setting controlled creation commands and filter choices, but the Mac
Timeline builders and Planner snapshot still consumed every persisted Event.
Planner then cached Event blocks without including Event availability in its cache
key, so presentation-only filter normalization could not enforce capability.

## Fix

Both Mac Timeline presentations now pass an empty Event catalog while the feature
is unavailable. Planner gates Events before deriving timed blocks, all-day blocks,
occupied intervals, and its immutable render snapshot, and includes capability in
the snapshot key. Event editors, relationships, deep links, Settings sources, and
notifications follow the same gate while stored data remains intact.

## Prevention Rule

Apply an optional persisted feature's capability before any cached presentation
derivation, and include the capability in every cache signature whose output it
changes. Hiding a filter control is not a data-membership boundary.

## Regression Safeguard

`PerformanceRegressionTests` verifies that both Mac Timelines and Planner gate
Event inputs and cache availability. `AppFeatureTests` protects disabled Event
deep links, while `SettingsIOSRelevanceTests` protects cross-platform task and
Settings boundaries. The unavailable-Event regression scenario covers the full
release contract.

Related decision: [0711 — Gate Disabled Events Across Mac Release Surfaces](../decisions/0711-gate-disabled-events-across-mac-release-surfaces.md).
