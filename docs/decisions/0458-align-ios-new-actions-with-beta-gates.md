# 0458: Align iOS New Actions With Beta Gates

## Status

Accepted

## Date

2026-07-29

## Refines

- [0173: Use iOS New Tab Sheet](0173-use-ios-new-tab-sheet.md)
- [0212: Hide Goal Tab by Default on iOS](0212-hide-goals-tab-by-default.md)
- [0220: Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
- [0221: Hide Stats Sleep Tab Behind Beta Toggle](0221-hide-stats-sleep-tab-behind-beta-toggle.md)

## Context

The iOS New sheet filtered Notes, Check In, Away, and its dedicated Sleep
shortcut preference, but it always exposed Event, Emotion, and Goal. It also
ignored the Sleep beta setting. As a result, turning related experiments off
removed their navigation or reporting surfaces while leaving creation or start
actions available from the global New tab.

The New sheet is a global entry point, so feature availability must apply there
as consistently as it does to tabs, filters, reports, and other creation
surfaces.

## Decision

The iOS New sheet derives every optional row from its corresponding persisted
feature availability:

- Event and Emotion require `Show Event and Emotion actions`.
- Goal requires `Show Goals tab`.
- Going to sleep requires Away, the nested Sleep beta experiment, and the
  dedicated `Show Going to sleep in New sheet` shortcut preference, and remains
  hidden while a Sleep session is active.
- Note, Check In, and Away continue to follow their existing Notes, Places, and
  Away gates.
- Task remains always available.

iOS Beta Experiments exposes `Show Event and Emotion actions`. The existing
persisted Event/Emotion key is reused, including its legacy Mac-oriented raw
name, so existing preferences remain compatible.

Action routing and modal content repeat the same availability checks instead of
trusting only the visible row filter. This prevents stale or queued selections
from opening a feature after its setting becomes unavailable.

## Consequences

- Turning an experiment off removes its matching iOS New-sheet entry point.
- Default iOS New contains only actions whose features are currently enabled.
- The dedicated Sleep shortcut preference can further hide Sleep but cannot
  override disabled Away or Sleep experiments.
- Existing Event, Emotion, Goal, and Sleep data remains readable wherever its
  separate read-only presentation rules allow it.
