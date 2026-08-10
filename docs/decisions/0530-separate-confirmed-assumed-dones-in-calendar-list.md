# 0530: Separate Confirmed Assumed Dones in Calendar List

## Status

Accepted

## Date

2026-08-10

## Refines

- [0370: Confirm Assumed-Done Rows Inline](0370-confirm-assumed-done-rows-inline.md)
- [0509: Collapse Calendar List Assumed-Done Sections](0509-collapse-calendar-list-assumed-done-sections.md)
- [0529: Collapse Calendar List Planned Task Sections](0529-collapse-calendar-list-planned-task-sections.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Confirming an assumed-done Calendar List row records a real completion, but
placing that record in `Dones` makes it indistinguishable from work recorded
without an assumption. The person explicitly reviewed the assumption, so the
Calendar List should retain that context without weakening the completion's
normal history, Stats, or task-lifecycle semantics.

## Decision

Mac Calendar `List` displays a `Confirmed assumed done` section between
`Assumed done` and `Dones`. Selecting an assumed-done row's green check moves
the visible row immediately into that section. A persisted
`isConfirmedAssumedDone` marker on its completion log retains the category
after refresh, backup/restore, and direct iCloud import.

The marker is set only by the assumed-completion confirmation path. Existing
completion history remains in `Dones`; Routina does not infer an old log's
origin from matching time, cadence, or task settings. Confirmed assumptions
remain real completed occurrences: completion counts, linked-task fulfillment,
Task Detail editing, notifications, and all non-Calendar-List presentation
keep their established behavior. The focused right-side Planner day-task
sidebar continues to group these completed rows under `Dones`.

The Calendar List continues to consume its cached day-task snapshot. The new
marker is carried in that snapshot's activity signature, and the immediate
transition remains a local overlay rather than a history fetch or regrouping
operation during scrolling.

## Consequences

- Calendar List distinguishes confirmed assumptions from independently
  recorded completion rows without changing completion data semantics.
- New confirmation metadata survives normal backup and direct iCloud import.
- Legacy completion rows retain their familiar `Dones` presentation until a
  person explicitly confirms a new assumption.
- The right-side Planner day-task sidebar and Calendar List disclosure defaults
  remain otherwise unchanged.
