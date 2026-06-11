# 0213: Hide Goal UI on macOS by Default

## Status

Accepted

## Date

2026-06-12

## Context

macOS now includes a default-visible Goal tab and Goal add/edit affordances in task forms by default. The app already exposes a persisted setting `appSettingGoalsTabEnabled` for this behavior on iOS, and Mac should share the same visibility contract.

## Decision

- Add the existing `appSettingGoalsTabEnabled` key as the visibility gate for macOS Goal surfaces.
- Hide the macOS main Goal tab in `AppView` unless `appSettingGoalsTabEnabled` is enabled.
- Hide Goal sections/buttons in macOS task creation/edit section navigation and task-detail “Add More” actions unless `appSettingGoalsTabEnabled` is enabled.
- Add a toggle in macOS Settings → General (“Show Goals tab”) so users can enable the Goal tab and related controls if they want.

## Consequences

- By default, macOS starts without Goal tab content visible and without goal add buttons in task detail and form navigation.
- Users can still access goals by enabling the setting in Settings.
