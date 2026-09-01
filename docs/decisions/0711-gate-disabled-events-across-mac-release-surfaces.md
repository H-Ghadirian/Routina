# 0711: Gate Disabled Events Across Mac Release Surfaces

## Status

Accepted

## Date

2026-09-01

## Revises

- [0220: Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
- [0291: Gate Planner Calendar Filter Options by Beta Toggles](0291-gate-planner-calendar-filter-options-by-beta-toggles.md)
- [0710: Gate Disabled Events Across iOS Release Surfaces](0710-gate-disabled-events-across-ios-release-surfaces.md)

## Refines

- [0227: Gate Stats Goal and Event Reports](0227-gate-stats-goal-event-reports.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0470: Keep Beta Experiments Out of Production](0470-keep-beta-experiments-out-of-production.md)
- [0705: Refresh Cross-Platform Development Screenshot Fixtures](0705-refresh-cross-platform-development-screenshot-fixtures.md)

## Context

The current Mac release does not let production users create Routina standalone
Events. The effective Event/Emotion experiment was already off in production,
and its Add-menu and filter choices were hidden, but preserved Event records
still entered both Mac Timeline presentations and Planner Calendar. A development
store prepared for release screenshots could therefore show Event blocks while
the visible Events filter was unavailable and off.

The earlier Mac contract intentionally kept saved Events readable when creation
was disabled. That now contradicts the release boundary: an unavailable feature
must not be advertised by preserved data. The data should remain forward-compatible
rather than being deleted.

## Decision

- macOS derives standalone Event presentation from the effective Event/Emotion
  experiment setting. Production resolves that setting to unavailable.
- While unavailable, preserved Events do not enter the integrated or standalone
  Mac Timeline, Planner timed or all-day blocks, occupied-time derivation, or
  Event detail presentation. Planner presentation-cache signatures include the
  capability so changing it cannot reuse an Event-bearing snapshot.
- Event creation, editors, Add/Edit Task relationship sections, Task Details
  relationships, and Event deep links are unavailable while the setting is off.
  A stale editor or selected Event detail is dismissed.
- Mac Stats, Tags, scheduled-notification presentation, notification
  reconciliation, and explanatory copy follow the same effective capability.
  Tag rename and deletion do not mutate hidden Event tags.
- Existing Event records and task Event-link IDs remain stored, synchronized,
  backed up, restored, reset with complete user data, and recoverable if a
  development build enables the experiment again.
- Apple Calendar review remains available because it imports external calendar
  entries as tasks and is not Routina's standalone Event feature.

## Consequences

- Turning Events off removes Event evidence as well as Event controls on Mac.
- Release screenshots cannot imply that standalone Event creation is available.
- Development can still test Event capture and presentation deliberately by
  enabling the experiment.
- Event availability is an explicit input to cached Planner presentation instead
  of an unchecked persisted-data side channel.
