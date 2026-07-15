# 0392: Show Focus Time in Calendar List Dones

Date: 2026-07-15

Status: Accepted

Refines: [0205 Run Plan Focus From Planner](0205-run-plan-focus-from-planner.md), [0209 Allocate Plan Focus While Running](0209-allocate-plan-focus-while-running.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)

## Context

Planner Calendar has two task presentations: editable `Schedule` and read-only `List`. List columns reuse the day agenda sections: `Planned tasks`, `Assumed done`, and `Dones`.

Persisted tag and unassigned focus blocks are stored as planner evidence so focus time can be shown on the calendar. Because they share the timed planner block model, Calendar `List` could classify them as `Planned tasks`, which made recorded focus time look like unresolved planned work.

## Decision

Calendar `List` and the right-side day agenda classify visible unassigned/tag focus time rows as `Dones`.

Those rows keep their title, time range, duration, Calendar search behavior, and Focus layer visibility. This is a presentation classification only: it does not turn focus sessions into task completions, change editable `Schedule` block behavior, or make focus rows draggable as task work.

## Consequences

- Recorded focus time no longer inflates `Planned tasks` counts in Calendar `List` or the day agenda.
- Focus review stays available in the day-level task summary without mixing it into task completion logs.
- Schedule remains the editing surface for timed planner blocks; List remains a read-only review surface.
