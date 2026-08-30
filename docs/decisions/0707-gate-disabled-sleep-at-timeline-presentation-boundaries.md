# 0707: Gate Disabled Sleep at Timeline Presentation Boundaries

## Status

Accepted

## Date

2026-08-31

## Refines

- [0220: Nest Sleep and Gate Mac Event/Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
- [0221: Hide Stats Sleep Tab Behind Beta Toggle](0221-hide-stats-sleep-tab-behind-beta-toggle.md)
- [0279: Hide Sleep Stats and Blocking With Away Toggle](0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
- [0706: Gate Disabled Emotions at Release Presentation Boundaries](0706-gate-disabled-emotions-at-release-presentation-boundaries.md)

## Context

Timeline already removed the Sleep type choice when either Away or the Sleep
experiment was unavailable, but its `All` presentation still consumed every
persisted `SleepSession`. The development screenshot fixture therefore exposed
Sleep rows even though a production user cannot start Sleep with the default
release settings.

Persisted Sleep history still needs to survive synchronization, backup, and
later development re-enablement. The feature gate therefore belongs at the
Timeline presentation boundary rather than in storage cleanup.

## Decision

- iOS and both macOS Timeline presentations include Sleep rows only while both
  `Show Away` and `Show Sleep tab` are enabled.
- Changing either setting rebuilds Timeline membership as well as normalizing
  an unavailable Sleep filter back to `All`.
- Persisted Sleep records remain stored and become visible again when both
  development settings are enabled.
- Release screenshot fixtures may retain representative Sleep records for
  development testing, but those records cannot leak into the default release
  Timeline story.

## Consequences

- Default production Timeline surfaces do not advertise unavailable Sleep
  logging.
- Feature availability is consistent between Timeline choices and row
  membership on iOS and macOS.
- No Sleep history is deleted or rewritten by presentation changes.
