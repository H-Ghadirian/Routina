# 0280 — Gate optional records beyond filter controls

Date: 2026-08-31

## Symptom

iOS Timeline showed standalone Event rows under `All` even though Event creation
and Event filters were disabled for the first release. Other iOS surfaces could
still expose Event reports, relationships, deep links, and Settings language.

## Root Cause

The Event/Emotion setting controlled creation and filter choices, but several
consumers read persisted Event data directly. Stats also omitted Event from the
same availability switch that already covered Emotion, and the release fixture
continued to manufacture Event records.

## Fix

iOS now applies the effective Event/Emotion capability to Timeline membership
and detail routing, Stats reports, task relationship UI, deep links, Tags,
scheduled-notification presentation, and notification reconciliation. The
release fixture creates no Events and retires only its two reserved Event rows.
Persistence, sync, complete backups, and hidden task links remain intact.

## Prevention Rule

For an optional persisted record type, inventory every outward path: creation,
filter choice, list membership, detail and deep-link routing, reports,
relationships, Settings copy, notifications, fixtures, and empty states. A
feature is not unavailable merely because its creation button and filter are
hidden.

## Regression Safeguard

`IOSNewTabActionAvailabilityTests`, `StatsDashboardItemAvailabilityTests`,
`AppFeatureTests`, `SettingsIOSRelevanceTests`, and
`RoutinaScreenshotDataSeederTests` protect the iOS Event gates and fixture
retirement. The unavailable-iOS-Event and screenshot-preparation scenarios
record the release contract.

Related decision: [0710 — Gate Disabled Events Across iOS Release Surfaces](../decisions/0710-gate-disabled-events-across-ios-release-surfaces.md).
