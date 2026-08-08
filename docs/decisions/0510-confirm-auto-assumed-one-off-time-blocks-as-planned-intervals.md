# 0510 — Confirm Auto-Assumed One-Off Time Blocks as Planned Intervals

Status: Accepted

Date: 2026-08-08

Refines: [0036 Treat Completion Times as Planner Finish Times](0036-treat-completion-times-as-planner-finish-times.md), [0435 Edit Calendar List Done Times From Mac Task Detail](0435-edit-calendar-list-done-times-from-mac-task-detail.md), [0444 Log Completion Duration Without a Specific Time](0444-log-completion-duration-without-a-specific-time.md), and [0492 Allow Auto-Assume Done for One-Off Scheduled Blocks](0492-allow-auto-assume-done-for-one-off-scheduled-blocks.md)

## Context

An eligible one-off task with one exact date and a scheduled Time block becomes
synthetically assumed done when its block starts. Before confirmation it has no
completion history, as required by [0492](0492-allow-auto-assume-done-for-one-off-scheduled-blocks.md).

Previously, confirming that assumption used the current clock time and the
generic completion-duration default. The resulting recorded Done therefore did
not represent the scheduled interval that had been assumed, and the Mac `Done
this day` editor opened with an unrelated time range. Task Detail also omitted
the one-off block's exact schedule while showing separate reminder metadata.

## Decision

Task Detail shows an eligible one-off `Time block` as `Schedule` metadata with
its exact date and start/end range, independently of a reminder.

When the person confirms the currently synthetic assumed occurrence for that
same task, Routina records the scheduled block as specific-time completed work:

- the completion log timestamp is the block end;
- the actual duration is the full start-to-end interval; and
- `hasSpecificWorkTime` is `true`.

For one-off tasks, the task-level actual duration is kept synchronized with that
recorded duration. This preserves the established finish-time completion
identity and lets the existing Mac `Done this day` editor derive the block start
from its timestamp and duration.

Manual completion of a task that is not currently assumed done is unchanged,
as are flexible windows, exact-time tasks, recurring assumptions, and the rule
that unconfirmed assumptions create no history.

## Consequences

- Confirming an assumed one-off 12:00–15:00 block records 15:00 and 180
  minutes, so review and stats use the intended interval.
- Task Detail keeps availability/schedule information visible after the one-off
  is completed or while it is assumed done.
- The scheduled Planner block remains planning data; no Planner placement is
  created, moved, or edited by confirmation.
