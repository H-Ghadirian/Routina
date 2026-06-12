# 0219: Hide Stats Wins Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Context

Recent Wins is useful for reviewing rolling accomplishments, but it adds another Stats category and dashboard section to an already dense surface. Routina already uses Settings -> General -> Beta Experiments for optional or still-stabilizing surfaces while keeping the default UI quieter.

## Decision

Stats hides the Recent Wins dashboard section and the Wins dashboard scope by default. Users can enable them from Settings -> General -> Beta Experiments with the `appSettingStatsWinsEnabled` flag.

Saved Stats dashboard order and hidden-item preferences remain intact while Wins is disabled, so users who opt back in keep their previous dashboard customization.

## Consequences

- Default Stats navigation and dashboard content are quieter.
- Recent Wins remains implemented and user-accessible as an explicit beta experiment.
- iOS and Mac share the same preference key so the behavior is consistent across platforms.
