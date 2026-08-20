# 0615: Group and Control Pending Notification Occurrences

## Status

Accepted

## Date

2026-08-18

## Revises

- [0611: List Actual Pending Notifications in Settings](0611-list-actual-pending-notifications-in-settings.md)

## Refines

- [0192: Support Event Notifications](0192-support-event-notifications.md)
- [0210: Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)
- [0412: Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md)

## Context

A chronological list of system requests verifies what the device will deliver,
but it becomes difficult to scan when one Advanced task contributes many
occurrences. People also need to postpone or skip one alert without editing the
task's cadence, deadline, completion state, event time, or every later alert.

Simply removing a system request is insufficient because Routina rebuilds its
bounded notification schedule after task changes, app reconciliation, imports,
and notification-setting changes. The removed occurrence would otherwise be
queued again.

## Decision

Settings -> Notifications groups pending requests by their originating task or
event. Groups are ordered by their earliest queued alert. Selecting a group
expands the chronological list of pending occurrences for that source.

Each occurrence offers two device-local actions:

- `Remove` skips that occurrence only.
- `Pause` postpones that occurrence by 15 minutes, one hour, until tomorrow, or
  a chosen later date and time.

These actions do not change task or event data, recurrence, deadline, reminder,
completion state, or another device. A paused row shows its new delivery time
and its original time.

Routina writes a small device-local scheduling override before changing the
system request. An override is keyed by the stable source identifier and the
original occurrence time rounded to the same minute precision as the system
trigger. Notification content carries that identity so Advanced request-index
changes do not lose the person's choice. Reconciliation omits skipped
occurrences and preserves a paused occurrence's replacement time. Expired
override records are pruned after a bounded retention period and remain outside
SwiftData, CloudKit, and backups.

The visible total remains a count of actual queued occurrences, while each
group separately shows its occurrence count. The operating system remains the
source of truth for which requests are currently pending.

## Consequences

- A person can scan alerts by task or event and inspect only the relevant
  occurrences.
- Removing or pausing one Advanced occurrence does not affect its siblings or
  later recurrence behavior.
- Schedule rebuilds respect the device-local action instead of recreating the
  original request.
- The same task can legitimately show different pending occurrences and paused
  times on different devices.
