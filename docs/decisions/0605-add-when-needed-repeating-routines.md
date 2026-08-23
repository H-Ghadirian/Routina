# 0605 — Add a When-Needed Repeating Routine Mode

Date: 2026-08-18
Status: Accepted

Refines: [0421](0421-support-cadence-free-repeating-routines.md), [0524](0524-pause-tasks-until-a-date.md)

## Context

Some responsibilities repeat, but the person cannot predict the next occurrence. Existing `No schedule` correctly keeps that work reusable, but it remains active immediately after completion. That is noisy for responsibilities where completing the current occurrence means waiting until the person decides the next occurrence is needed.

## Decision

Add a distinct `When needed` cadence to the repeating-task editor on Add Task, Edit Task, and Task Details. It uses the same cadence-free recurrence storage as `No schedule`, but persists an `autoPauseAfterCompletion` behavior flag for routines.

When a `When needed` task completes an occurrence, the completion flow sets its existing indefinite pause state at the completion time and clears any pause expiry or snooze value. The task therefore leaves active projections while preserving its completion history and recurrence configuration. The existing `Resume` action clears the lifecycle pause without changing the `When needed` configuration, so the next completion pauses it again. Undoing the latest completion clears the automatic pause when its timestamp matches that completion; a manually paused task is not changed by undoing an unrelated completion.

The setting is included in SwiftData, CloudKit shared-task payloads, direct-pull recovery, backup/import, detached copies, and creation-draft persistence. Older records and drafts default to the existing behavior. `No schedule` remains unchanged and continues to stay active after completion.

## Consequences

- People can keep an unknown-cadence responsibility without recreating it or leaving it active between uses.
- `No schedule` and `When needed` remain visibly separate even though both have no automatic cadence.
- The app reuses the established pause/archive and Resume lifecycle across platforms, projections, sync, and history correction.
- The new persisted behavior requires the corresponding CloudKit schema field to be deployed before a release that writes it.
