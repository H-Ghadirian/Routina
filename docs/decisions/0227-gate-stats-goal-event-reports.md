# 0227: Gate Stats Goal and Event Reports

## Status

Accepted

## Date

2026-06-13

## Refines

- [0212](0212-hide-goals-tab-by-default.md)
- [0213](0213-hide-goals-ui-by-default-on-macos.md)
- [0220](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)

## Context

Goals and Mac Event/Emotion actions are beta-gated so default navigation and capture surfaces stay focused. Stats still exposed Goal and Event summary reports when those same feature gates were disabled, which made the disabled features visible through the dashboard.

## Decision

Stats report availability follows the same beta feature gates as the related surfaces:

- When `appSettingGoalsTabEnabled` is disabled, Stats hides Goal summary cards and Goal Momentum reports.
- On macOS, when `appSettingMacEventEmotionActionsEnabled` is disabled, Stats hides Event and Emotion summary cards plus Emotion Trend reports.

Saved dashboard order and hidden-item preferences are preserved while items are unavailable, so enabling the beta flag later restores the user's previous dashboard customization.

## Consequences

- Default Stats dashboards no longer surface disabled Goal, Event, or Emotion features.
- Settings copy describes that the beta toggles affect Stats reports as well as navigation and capture controls.
- No data migration is needed because only dashboard availability changes.
