# 0380 Add Record Task Type

Status: Accepted

Date: 2026-07-13

Refines: [0045 Split Routine Schedule Behavior and Format](0045-split-routine-schedule-behavior-and-format.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0347 Split Mac Future Tag Groups By Task Kind](0347-split-mac-future-tag-groups-by-task-kind.md), [0359 Show Assumed Done Stats Summary](0359-show-assumed-done-stats-summary.md)

## Context

Todos answer what needs to be finished once. Routines answer what should recur or remain gently visible. Neither is a clean fit for after-the-fact logs such as analysis notes, work records, or time-spend entries.

Users need a task-like object for remembering what happened and analyzing how time was spent without creating overdue pressure, repeat configuration, or planned-date behavior.

## Decision

Routina adds a third task type, `Record`, represented by a dedicated `RoutineScheduleMode.record` value and `RoutineTaskType.record`.

Records share the task model so they can use names, notes, links, tags, goals, places, media, attachments, estimates, actual duration, focus timer metadata, archive state, search, and Stats/Timeline filtering. They do not expose or persist due dates, reminders, date availability, all-day/time availability, planned dates, routine duration, routine repeat controls, routine steps, or routine checklist cadence. Their recurrence columns normalize to a neutral one-day interval only for storage compatibility and should not be presented as a repeat.

Home, Stats, Timeline, task-list mode controls, advanced search aliases, and tag task-kind splitting treat Records as a separate kind alongside Todos and Routines. Records count as active task rows while active and unarchived, following the existing active-task usage gate.

## Consequences

Users can log work and time-spend analysis without making fake todos or routines.

Future task-type logic should branch on `scheduleMode.taskType` or `RoutineTaskType`, not on `isOneOffTask` alone, so Records do not accidentally inherit Todo or Routine behavior.

Any new scheduling, planning, deadline, reminder, checklist-cadence, or overdue behavior must explicitly opt Records in; the default is that Records remain unscheduled analysis entries.
