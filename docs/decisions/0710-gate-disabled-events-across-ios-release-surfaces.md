# 0710: Gate Disabled Events Across iOS Release Surfaces

## Status

Accepted

## Date

2026-08-31

## Revises

- [0220: Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
- [0705: Refresh Cross-Platform Development Screenshot Fixtures](0705-refresh-cross-platform-development-screenshot-fixtures.md)

## Refines

- [0227: Gate Stats Goal and Event Reports](0227-gate-stats-goal-event-reports.md)
- [0470: Keep Beta Experiments Out of Production](0470-keep-beta-experiments-out-of-production.md)
- [0703: Keep iOS Settings Platform-Relevant and Adaptive](0703-keep-ios-settings-platform-relevant-and-adaptive.md)
- [0706: Gate Disabled Emotions at Release Presentation Boundaries](0706-gate-disabled-emotions-at-release-presentation-boundaries.md)

## Context

The first iPhone release does not include Routina's standalone Event feature.
Production already forced the shared Event/Emotion experiment off, and iOS
removed Event creation and filter choices, but Timeline still passed every
persisted Event into `All`. Event reports, task relationships, deep links, and
some Settings language also remained reachable independently. The release
screenshot fixture then made the mismatch visible by creating two Event rows.

The older Mac-focused Event decision deliberately kept existing Event rows
readable when creation was disabled. That behavior is not appropriate for an
iPhone release whose users cannot create or otherwise use Events. External
Apple Calendar events remain a different concept: reviewing them and importing
them as tasks is a released Calendar integration, not standalone Event capture.

## Decision

- iOS derives standalone Event presentation from the effective Event/Emotion
  experiment setting. Production resolves that setting to unavailable.
- While unavailable, Event records do not enter iOS Timeline under `All`, Event
  filters stay absent, Event deep links are ignored, and stale Event detail
  presentation is dismissed.
- iOS Stats excludes the Event report from its available dashboard catalog.
- iOS Add/Edit Task and Task Details omit Event relationship sections and
  actions. Existing linked Event IDs remain stored and survive an iOS edit.
- iOS Settings omits standalone Event sources from Tags, scheduled-notification
  groups, and their explanatory copy. Notification reconciliation schedules
  Event notifications only while the feature is enabled. Tag rename and delete
  operations do not silently mutate hidden Event tags. Event data remains in
  complete backup, restore, sync, and reset operations.
- Apple Calendar task review and its use of the ordinary word “event” remain
  available because they import external calendar entries as tasks.
- The shared release screenshot fixture creates no Event records. A rerun
  removes only the two retired fixture-owned Event IDs and preserves unrelated
  development Events.
- Mac Event presentation outside the shared release fixture keeps its existing
  platform contract until a separate Mac decision revises it.

## Consequences

- The first iPhone release cannot advertise a standalone feature that users
  cannot access.
- Development can still test Event presentation by enabling the experiment and
  creating development records deliberately.
- Hidden Event data remains forward-compatible rather than being deleted by a
  presentation change.
- Future optional record types must gate creation, filters, membership, detail
  routing, reports, relationships, Settings language, notifications, and release
  fixtures from the same effective capability.
