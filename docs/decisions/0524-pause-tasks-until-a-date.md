# 0524 — Pause Tasks Until a Date

Date: 2026-08-09
Status: Accepted

Refines: [0487](0487-allow-archiving-one-off-tasks.md), [0521](0521-group-secondary-mac-task-detail-actions.md)

## Context

An indefinite pause is useful when a task has no foreseeable return date, but it
forces a person to remember to restore work that should become actionable again
on a known date. Leaving paused work in Planner also makes a schedule look
actionable when it is not.

## Decision

Tasks retain their pause start and may also retain an optional `pauseUntil`
instant. A missing expiry keeps the existing indefinite Pause / Archive behavior.
Before the expiry instant, the task is paused; at and after that instant it is
active again without a manual restore. This is a derived lifecycle state, so it
works consistently after an app relaunch, on another device, or while an app was
not running at the exact expiry time.

Task Detail offers an explicit `Pause Until…` action for routines and `Archive
Until…` for one-off tasks alongside the existing indefinite action. The picker
uses a local date and time. A person may still resume a task early, which clears
both pause values and retains the existing manual-resume schedule behavior.

While a task is paused, Planner excludes it from task pickers, automatic blocks,
stored task blocks, all-day task blocks, and date-only planned-task projections.
The underlying plan and task history are preserved. After expiry, the normal
planner projections become eligible again according to their original schedule.

The optional expiry is included in SwiftData/CloudKit replication, direct sync
recovery, shared-task payloads, backup/export, and import. It is a new CloudKit
schema field and must be deployed to Production before a build that writes it is
released.

## Consequences

- Users can defer a task to an exact time without creating a duplicate task or
  relying on a reminder to resume it.
- The Calendar schedule is an actionability view, not a list of paused work.
- The product does not attempt to run in the background at the expiry moment;
  lifecycle state is evaluated from the persisted dates whenever the app or an
  extension observes the task.
