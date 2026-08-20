# 0611: List Actual Pending Notifications in Settings

## Status

Accepted

The read-only presentation portion is revised by
[0615: Group and Control Pending Notification Occurrences](0615-group-and-control-pending-notification-occurrences.md).

## Date

2026-08-18

## Refines

- [0185: Limit Exact-Date Reminders to Todos](0185-limit-exact-reminders-to-todos.md)
- [0192: Support Event Notifications](0192-support-event-notifications.md)
- [0412: Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md)

## Context

People can inspect an exact reminder on an individual todo or event, but that
does not answer which alerts the current device will actually deliver. Routine
alerts are derived from cadence, availability, and due state; Advanced
recurrence can queue several occurrences for one task; and notification
permission, pausing, archiving, completion, or auto-assume behavior can prevent
an otherwise scheduled item from having a pending request.

Reconstructing a list from task and event data would therefore confuse intended
schedules with notifications that are actually registered with the operating
system.

## Decision

Settings -> Notifications on iOS and macOS shows a read-only chronological list
of the app's pending local notification requests. The system notification center
is the source of truth. Each row uses the queued request's title, explanatory
text, and next trigger date; requests with an unavailable date appear after
dated requests.

The list refreshes when Settings loads, when the app becomes active, and after
Routina enables, disables, or reschedules notifications from notification
settings. It presents a loading state, an authorization-aware empty state, and
the number of currently queued requests. Multiple pending Advanced recurrence
occurrences remain separate rows because each one is a real future alert.

The list is device-local and includes pending requests only. It does not include
delivered notifications, reconstruct unscheduled future possibilities, persist
a second notification ledger, or treat Planner and Calendar entries as proof
that an alert is queued.

## Consequences

- A person can verify every alert currently scheduled on the device from one
  place.
- The count is a count of queued occurrences, not distinct tasks or events.
- Different devices can show different lists because local authorization and
  pending requests are not synchronized data.
- Notification scheduling remains authoritative; Settings only observes its
  result and cannot drift through a separately maintained index.
