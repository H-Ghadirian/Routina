# 0410: Show Assumed-Done Home Rows by Default

## Status

Accepted

## Date

2026-07-20

## Supersedes

- [0260: Hide Assumed-Done Tasks by Default](superseded/0260-hide-assumed-done-tasks-by-default.md)
- [0262: Use Positive Assumed-Done Filter Copy](superseded/0262-use-positive-assumed-done-filter-copy.md)

## Refines

- [0252: Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md)
- [0259: Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md)
- [0398: Move Auto-Assume Done to Tracking](0398-move-auto-assume-done-to-tracking.md)

## Context

After auto-assume moved to Tracking, assumed-done rows became part of the
tracking review workflow rather than routine-list noise. Hiding them behind a
Home filter made it too easy to miss the current assumed state and the inline
confirm or missed correction actions.

The old temporary-view-state field still exists in saved snapshots and backups,
so the app needs to remain compatible with older data without allowing that
stale flag to suppress rows.

## Decision

Home shows assumed-done task rows by default.

The `Show assumed done` Home filter control is removed from iOS and macOS filter
surfaces. The shared Home task-list predicate no longer excludes assumed-done
rows, and stale `hideAssumedDoneTasks` values are normalized to the visible
state when Home filter state is reset, restored, or persisted.

The compatibility field remains readable for older temporary state and snapshot
payloads, but it no longer counts as an active filter, no longer appears in
filter summaries, and no longer changes task-list membership.

Planner's separate Calendar `Assumed done` layer remains unchanged; this
decision only changes Home task-list visibility.

## Consequences

- Assumed-done Tracking rows stay visible in Home so users can review, confirm,
  or mark the assumed day missed without opening Filters.
- The Home filter surface is simpler because assumed-done visibility is no
  longer user-configurable there.
- Legacy saved hidden-state values remain compatible but become inert.
