# 0406 Auto-Plan Exact-Date Todos

Status: Accepted

Date: 2026-07-18

Refines: [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0350 Add Optional Mac Tomorrow Task Section](0350-add-optional-mac-tomorrow-task-section.md)

## Context

Todo date availability and `Plan to do` were originally separate: availability described when a todo could be done, while planning described where it should appear in the working list. That separation still works for `Any date` and `Date window`, but it is awkward for `At date`.

When a one-off todo is available on one exact date, users expect the task to be planned for that same date. Without that automatic plan, a task available tomorrow can stay in `Future` instead of appearing in the enabled `Tomorrow` section, even though the form clearly shows a single exact date.

## Decision

For one-off todos, exact date availability automatically supplies the same normalized day as the task's planned date.

Add and edit forms reveal/activate `Planning` when date availability is `At date`, keep `Plan to do` set to that exact day, and snap attempted planning edits back to the exact availability date while the exact date is active.

Newly saved, edited, imported, shared, backed up, and directly constructed one-off todos derive the same planned date from exact availability. Existing stored tasks that have exact availability but no raw `plannedDate` are displayed with the effective planned date so they can appear in `Today` or enabled `Tomorrow` before being resaved.

`Any date` and `Date window` do not force planning. Planned dates remain separate from deadlines, reminders, completion history, and stored Planner blocks.

## Consequences

To clear or choose a different `Plan to do` date for a todo, the user must first move date availability away from `At date`.

The Mac `Tomorrow` section can claim exact-date todos for tomorrow, because their effective planned date is tomorrow. Pinned and custom-section placement keep their existing priority over planning placement.
