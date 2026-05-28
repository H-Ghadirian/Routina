# 0090: Support Manual All-Day Tasks in the Planner

- Status: Superseded by [0092](0092-support-all-day-routines.md)
- Date: 2026-05-28
- Supersedes: [0086](0086-show-all-day-calendar-events-in-planner.md)

## Context

Routina already shows imported all-day calendar events in the planner's all-day lane, but ordinary user-created tasks could not be added there. The only durable all-day signal lived in hidden calendar-import note metadata, which made the all-day lane useful for imports but not for first-class Routina tasks.

Users need to create and edit their own all-day todos without relying on calendar-import markers.

## Decision

Store manual all-day intent as first-class task data on `RoutineTask`. The task create and edit forms expose an All Day toggle for dated todos, and enabling it stores the todo deadline as a date-only all-day task.

The planner all-day lane renders dated one-off tasks whose first-class all-day flag is enabled. Imported calendar all-day events continue to render from calendar metadata first so multi-day imported spans keep their original start and end dates. Legacy date-only calendar imports remain a fallback for old data.

## Consequences

- Users can create all-day tasks directly in Routina and see them in the planner's all-day lane.
- All-day task state participates in backup, import, sharing, and CloudKit direct-pull repair as task data rather than hidden notes.
- Manual all-day tasks are currently one-day spans tied to their deadline date; multi-day spans remain a calendar-import capability unless a future task-span model is added.
