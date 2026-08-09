# 0528: Suppress Notifications for Auto-Assumed Tasks

## Status

Accepted

## Date

2026-08-09

## Refines

- [0500: Move Auto-Assume Done to Flag Rules](0500-move-auto-assume-done-to-flag-rules.md)

## Context

An active auto-assume rule presents the task's current occurrence as
synthetically complete. Scheduling a due alert or direct reminder for the
same task asks the person to act on work Routina has already marked assumed
done, producing contradictory notifications.

## Decision

When a task has active auto-assume behavior, Routina does not schedule task
notifications for it. This covers automatic due alerts and direct task
reminders. The `Hide tasks from normal task lists` Flag rule remains purely a
presentation rule and continues not to affect notifications.

## Consequences

- Adding, editing, importing, or otherwise reconciling an auto-assumed task
  removes any pending task alert instead of scheduling another one.
- A task starts receiving notifications again when auto-assume behavior is no
  longer active.
- Notification eligibility and synthetic-completion eligibility remain one
  shared contract rather than independently interpreting a task's schedule.
