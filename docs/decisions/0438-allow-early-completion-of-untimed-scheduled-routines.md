# 0438 — Allow Early Completion of Untimed Scheduled Routines

Status: Accepted

Date: 2026-07-26

Refines: [0036 Treat Completion Times as Planner Finish Times](0036-treat-completion-times-as-planner-finish-times.md), [0412 Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md), [0431 Present One Progressive Recurrence Composer](0431-present-one-progressive-recurrence-composer.md)

## Context

An `On schedule` routine can represent a deadline-like obligation, such as rent due on the 27th. Users may finish that obligation before its scheduled day. Task Detail displayed an enabled Done action on an earlier day, but recurrence validation rejected the action without feedback.

Treating the actual completion timestamp as the recurrence cursor would leave the imminent scheduled occurrence due. Treating the future scheduled timestamp as the completion would move history and Timeline evidence to a day when the work did not happen.

## Decision

Task Detail allows early completion of active, single-occurrence, untimed, one-day scheduled routines. Home actions, notifications, exact-time or time-window routines, subdaily schedules, checklist-completion and item-runout routines, and multi-day lifecycles retain their existing actionability boundaries.

Early completion stores two related dates:

- The completion log timestamp and `lastDone` record when the user actually finished the routine.
- The log's `scheduledOccurrenceAt` and the task's `lastSatisfiedScheduledOccurrenceAt` identify the scheduled occurrence that was satisfied.

Future due-date calculation advances from the satisfied scheduled occurrence, so completing rent on July 26 for its July 27 occurrence makes the next due date August 27. Undo restores both the latest actual completion and its scheduled-occurrence cursor. Backup/import, CloudKit direct pull, and task sharing preserve both values.

## Consequences

- Users can pay or finish untimed scheduled obligations early from Task Detail without shifting the fixed calendar rule.
- Timeline and statistics keep the real completion day.
- The recurrence engine can distinguish actual activity time from occurrence identity.
- Timed and multi-occurrence schedules remain protected from ambiguous early resolution.
- New completion entry points must opt into early scheduled completion explicitly rather than weakening global due-state actionability.
