# 0706: Gate Disabled Emotions at Release Presentation Boundaries

## Status

Accepted

## Date

2026-08-30

## Revises

- [0705: Refresh Cross-Platform Development Screenshot Fixtures](0705-refresh-cross-platform-development-screenshot-fixtures.md)

## Refines

- [0220: Nest Sleep and Gate Mac Event/Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
- [0470: Keep Beta Experiments out of Production](0470-keep-beta-experiments-out-of-production.md)

## Context

Production disables the Event and Emotion experiment, but older development
fixtures created Emotion records. Creation controls and Timeline filter choices
honored the gate while iOS Stats and Timeline row membership still rendered
persisted Emotion data. This made release screenshots advertise a feature that a
production user cannot use.

Preserving optional-feature data for synchronization and later re-enablement is
still valuable. Hiding a creation control must therefore not mean deleting a
person's history, but a release fixture also must not manufacture evidence for a
feature that is absent from the release.

## Decision

- When Event and Emotion features are unavailable, iOS Stats excludes Emotion
  summary, trend, and achievement presentation even if Emotion records remain in
  persistence.
- iOS Timeline and both Mac Timeline presentations exclude Emotion rows while
  the feature is unavailable. Changing the development experiment immediately
  rebuilds Timeline membership as well as its filter choices.
- Preserved Emotion records remain stored, synchronized, backed up, and
  recoverable when the development experiment is enabled again.
- The cross-platform release screenshot fixture no longer creates Emotion
  records. On its next run it removes only the ten Emotion records in its retired
  reserved ID range and leaves unrelated Emotion history untouched.
- Release fixtures may exercise internal experiments only when they cannot leak
  into the production-facing screenshot story. Unavailable feature evidence is
  excluded by default.

## Consequences

- Production Stats and Timeline cannot imply that Emotion logging is available.
- Development can still test Emotion presentation by enabling the experiment and
  using non-fixture records.
- Reseeding an existing development store cleans up the obsolete fixture records
  without erasing user-created development history.
- Screenshot preparation remains representative of the current release rather
  than every implemented experimental model.
