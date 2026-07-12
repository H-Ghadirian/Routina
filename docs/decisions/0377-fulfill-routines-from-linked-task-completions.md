# 0377: Fulfill Routines From Linked Task Completions

Date: 2026-07-12

Status: Accepted

Refines: [0124 Support Multiple Task Links](0124-support-multiple-task-links.md), [0259 Allow Daily Checklist Auto-Assumed Completion](0259-allow-daily-checklist-auto-assumed-completion.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0372 Hide Completed Tasks From Calendar Schedule](0372-hide-completed-tasks-from-calendar-schedule.md)

## Context

Some routines are satisfied by doing another task. For example, `Exercise routine` should be considered done when `Gym` is done, and also when `Hiking` is done. The link needs to be explainable without inflating activity history: doing Gym should not count as both Gym and Exercise in aggregate stats.

## Decision

Task links support a directional fulfillment relationship:

- `Done when` on the target routine means this routine is fulfilled when the linked source task is completed.
- `Completes` is the inverse wording from the source task.

When a source task is completed, Routina records a `fulfilled` log for each eligible linked target routine. Fulfilled logs store the source task ID, update the target routine's own done date, streak/calendar state, and hide the target from unresolved planner surfaces for that date.

Fulfilled logs do not count as aggregate completed activity. Stats and global timeline activity continue to count only direct `completed` logs. A target routine can have multiple source-specific fulfilled logs on the same day, but calendar and done-date presentation deduplicate by day, so the routine appears done once. Removing one source completion removes only fulfillments sourced by that task; another same-day source can keep the target fulfilled.

## Consequences

- Users can model "Exercise is done if Gym or Hiking is done" without double-counting the day.
- Task Detail can explain fulfilled history as `Done via <source task>`.
- Backup, import, and direct CloudKit pull preserve fulfilled logs and their source task IDs.
- Fulfillment is routine-oriented and conservative: archived tasks, one-off tasks, sequential-step routines, and checklist-runout routines are not fulfilled automatically.
