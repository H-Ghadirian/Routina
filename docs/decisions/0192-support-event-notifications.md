# 0192 Support Event Notifications

Status: Accepted

Date: 2026-06-09

Refines: [0092 Support Standalone Events](0092-support-standalone-events.md), [0185 Limit Exact-Date Reminders to Todos](0185-limit-exact-reminders-to-todos.md)

## Context

Standalone events are useful for calendar-visible happenings that should not behave like tasks. Decision 0092 intentionally kept events free of completion, overdue, recurrence, and reminder lifecycle semantics. Users still need a lightweight notification for a future event without creating a todo solely to be reminded about it.

Todo exact reminders remain separate from routine cadence and availability. Event notifications need the same one-time exactness as todos, but they should not add task actions, completion pressure, or recurring behavior to events.

## Decision

`RoutineEvent` supports an optional one-time `reminderAt` date. Event notifications are exact local notifications tied to the event record. They are scheduled only when app notifications are enabled, system notification authorization is available, and `reminderAt` is still in the future.

Event editor surfaces expose `Set notification` with the existing lead-time choices plus a custom date/time picker. For all-day events, the event reference time is the app's reminder time on the event start day; for timed events, it is the event start time.

Event notification content uses event wording, carries an event deep link, and does not use routine notification actions such as Done or Snooze. Tapping the notification opens the event in Timeline through `routina://event/<id>` or the matching development scheme.

Event reminder data participates in event backup/import payloads, creation drafts, CloudKit usage estimates, and notification rescheduling when notification settings or imported data are reconciled.

## Consequences

Events remain non-task records: no completion state, overdue pressure, recurrence behavior, checklist, or planner block persistence is added.

Future event notification work should stay event-scoped unless a separate decision introduces recurring events or richer calendar alarm rules.
