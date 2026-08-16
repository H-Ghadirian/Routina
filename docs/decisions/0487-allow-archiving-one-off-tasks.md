# 0487: Allow Archiving One-Off Tasks

## Status

Accepted

## Date

2026-08-06

## Refines

[0486 Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md)

Revised by: [0583 Keep Task Creation Unlimited](0583-keep-task-creation-unlimited.md)

## Context

One-off tasks may remain unfinished without being work a person currently wants
Routina to surface. Marking them done or canceled misstates that intent, while
the existing archived lifecycle state already excludes a task from
notifications, Home placement, and Help me choose. The Mac controls
previously exposed archiving only for repeating routines, despite the data model
and presentation layers supporting archived todos.

## Decision

Archiving is available for active one-off tasks as well as repeating routines.
On Mac, Task Detail exposes `Archive` / `Restore` in its toolbar and the Home
row context menu. Edit Task also includes the same action in its Danger Zone.
Repeating tasks retain their existing `Pause` / `Resume` language because their
cadence resumes after the pause; one-off tasks use `Archive` / `Restore` to
avoid implying a recurrence schedule.

An archived one-off task keeps all of its task data and is shown in Archived
until restored. It is unavailable to every guided `Add missing…` review,
Help me choose before metadata readiness, comparison, and ranking, and task
relationship review as either a source or candidate; it also does not receive
notifications. Restoring it clears only the archived state; it does not create
or shift a recurrence anchor.

## Consequences

- People can defer a one-off task without falsely marking it done or canceled.
- Suggestions consistently exclude archived work.
- Home uses task-specific labels without changing the established routine
  pause/resume behavior.
- The shared lifecycle state remains compatible with existing backup, sync, and
  archived-task presentation.
