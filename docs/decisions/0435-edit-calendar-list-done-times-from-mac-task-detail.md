# 0435 — Edit Calendar List Done Times From Mac Task Detail

Status: Accepted

Date: 2026-07-26

Refines: [0036 Treat Completion Times as Planner Finish Times](0036-treat-completion-times-as-planner-finish-times.md), [0296 Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)

## Context

Planner Calendar `List` is a review surface for planned, assumed-done, and recorded-done work. Selecting a row already opens Task Detail beside the calendar. For recorded Done rows, users need a direct way to correct when that work happened and how long it took for exactly the clicked day.

This is completion evidence, not planning. Editing a planned row’s Planner block would change the future-facing schedule and would not record the actual time spent on completed work.

## Decision

On macOS, opening a recorded task from a Planner Calendar `List` column carries the clicked day and the exact completion occurrence into the task-detail companion pane.

Task Detail shows a prominent `Done this day` card only for that contextual Done row. The card:

- displays the exact clicked date;
- presents `When` as the completed work’s start time;
- edits the completion’s actual duration;
- derives and stores the completion timestamp as start time plus duration;
- offers a time picker, duration stepper, common duration presets, end-time feedback, and one Save action.

For a normal recorded completion, Save updates that exact `RoutineLog.timestamp` and `RoutineLog.actualDurationMinutes`. A legacy `lastDone` fallback is materialized as a completion log before editing. One-off tasks also keep their task-level actual duration synchronized for existing Task Detail and Stats behavior.

Planned and assumed-done rows continue to open normal task details without this card. No `DayPlanBlock` is added, moved, resized, or removed. Recurrence, availability, reminders, estimates, other completion occurrences, and other days remain unchanged.

Calendar `List` columns remain read-only: the mutation surface is the separate task-detail companion pane.

## Consequences

- A user can select a Done row and correct the actual start time and duration without leaving Calendar `List`.
- The clicked completion-log identity prevents another day or occurrence from being edited accidentally.
- Planner placement and completion evidence remain separate.
- No persistence migration is needed because completion logs already store timestamps and actual durations.
