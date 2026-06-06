# 0171: Remove Default Check-In Activity Tags

## Status

Accepted

## Date

2026-06-06

## Refines

- [0014: Model Place Check-Ins as Place Sessions](0014-model-place-check-ins-as-place-sessions.md)
- [0023: Edit Place Check-Ins from the Day Timeline](0023-edit-place-check-ins-from-day-timeline.md)
- [0039: Move Mac Check-In to the Home Toolbar](0039-move-mac-check-in-to-home-toolbar.md)

## Context

Place check-ins previously exposed a fixed activity tag list: Work, Commute, Errands, Exercise, Rest, Social, and Other. Those defaults made the quick check-in menu feel heavier and implied a taxonomy that users had not chosen.

Place history still needs to read older sessions and backups that contain one of those values.

## Decision

New place check-ins no longer offer or apply built-in activity tags. The Mac toolbar menu, shared check-in dock, map check-in flow, automatic check-in reconciliation, and check-in editor do not present the fixed activity list.

The existing `PlaceCheckInActivity` values remain in the model for compatibility with older data, backup/import payloads, and display of historical tagged sessions. This change does not migrate or clear already stored activity values.

## Consequences

- Check-in capture is simpler and focuses on place, time, note, image, and location.
- Future activity categorization should be introduced as an explicit user-owned tagging model instead of hardcoded defaults.
- Existing tagged sessions remain readable, but users do not create new default-tagged check-ins through the current UI.
