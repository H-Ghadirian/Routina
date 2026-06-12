# 0224: Hide Stats Achievements Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Refines

- [0131](0131-show-general-achievement-badges.md)

## Context

Achievements provide long-term badge progress across Routina activity, but the Stats dashboard is now dense enough that default navigation should stay focused on the core activity summary and stable analysis scopes.

Routina already uses Settings -> General -> Beta Experiments for optional Stats scopes such as Recent Wins and Sleep, while keeping saved dashboard customization intact for users who opt those surfaces back in.

## Decision

Stats hides the Achievements dashboard section and the Achievements dashboard scope by default. Users can enable them from Settings -> General -> Beta Experiments with the `appSettingStatsAchievementsEnabled` flag.

Achievement calculations remain implemented as derived presentation state. Saved Stats dashboard order and hidden-item preferences remain intact while Achievements is disabled, so opting back in restores the prior dashboard customization.

## Consequences

- Default Stats navigation and dashboard content are quieter.
- Achievement badges remain available as an explicit beta experiment.
- iOS and Mac share the same preference key so achievement visibility stays aligned across platforms.
