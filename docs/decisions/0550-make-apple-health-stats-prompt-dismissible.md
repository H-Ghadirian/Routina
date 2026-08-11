# 0550: Make Apple Health Stats Prompt Dismissible

## Status

Accepted

## Date

2026-08-11

## Refines

- [0096: Show HealthKit Movement Stats in iOS Stats](0096-show-healthkit-movement-stats.md)
- [0113: Allow Stats Dashboard Reordering](0113-allow-stats-dashboard-reordering.md)

## Context

Apple Health is optional, but its pre-connection prompt occupied a fixed place
above the editable Stats dashboard. People who do not use the integration
could not remove that prompt, even though they could hide every ordinary Stats
section.

## Decision

While an Apple Health connection prompt is relevant, iOS treats it as a Stats
dashboard item. In Edit mode a person can hide it with the same remove control
as other dashboard items. `Add to Stats` restores it without granting,
revoking, or otherwise changing Apple Health permissions.

The prompt remains a dashboard item only while it needs to communicate Health
access, loading, or an error. Once Health metrics are ready, the prompt no
longer occupies dashboard space.

## Consequences

- People can keep Stats focused on the reports they use without connecting
  Apple Health.
- The prompt's visibility and position use the existing synced dashboard
  customization settings rather than a separate integration preference.
- Restoring the prompt remains a deliberate dashboard action; the app never
  prompts for Health access merely because the card becomes visible again.
