# 0277 — Align release fixtures with feature presentation gates

Date: 2026-08-30

## Symptom

The iOS release fixture made an Emotion chart visible in Stats and Emotion rows
visible in Timeline even though production disables Emotion logging.

## Root Cause

The fixture treated every implemented model as useful screenshot coverage, and
the Stats and Timeline read paths treated persisted Emotion records as sufficient
to render them. The creation and filter controls honored feature availability,
but the presentation membership did not.

## Fix

Stats and both platform Timeline presentations now gate Emotion evidence from
the effective Event/Emotion feature setting. The release fixture no longer
creates Emotion records and removes only the ten retired records in its reserved
ID namespace, preserving unrelated history.

## Prevention Rule

A release fixture must model the shipping feature set, not every implemented
schema. For optional features, gate record creation and every read-only
presentation boundary from the same effective capability, and retire only
fixture-owned records when release availability changes.

## Regression Safeguard

`RoutinaScreenshotDataSeederTests` verifies that the fixture contains no Emotion
records and retires only fixture-owned IDs. `StatsDashboardItemAvailabilityTests`,
`IOSNewTabActionAvailabilityTests`, and `PerformanceRegressionTests` protect the
iOS Stats and cross-platform Timeline presentation gates. The disabled-emotions
and screenshot-preparation scenarios record the release contract.

Related decision: [0706 — Gate Disabled Emotions at Release Presentation Boundaries](../decisions/0706-gate-disabled-emotions-at-release-presentation-boundaries.md).
