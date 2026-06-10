# 0200 Support Task Planned Dates

Status: Accepted

Date: 2026-06-10

Refines: [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0199 Support Multi-Day Routine Start Flow](0199-support-multiday-routine-start-flow.md)

## Context

Users need a lightweight way to say "I plan to do this task on this date" without turning that choice into a deadline, reminder, todo availability bound, or routine recurrence rule.

Availability answers when a task can be done. Deadline answers when it is due. Reminder answers when Routina should notify. Planned date answers where the user wants the task to appear in the working list for a day.

## Decision

Tasks store an optional `plannedDate` normalized to the start of the selected day.

Planned date is an optional More Details field for task creation/editing. It applies to one-off todos and non-daily routines as a planning hint, but it does not give routines fixed date availability and does not change a routine's one-day or multi-day duration choice.

Daily routines do not expose planning controls. They are already part of the user's daily work surface and remain in the always-today daily routine area instead of being individually planned. Checklist-driven item-runout routines only count as daily routines when at least one checklist item has a one-day runout cadence. The `Daily Routines` section stays separate from other grouping modes, including tag grouping and ungrouped task lists.

Home task lists show active, unpinned tasks planned for the current reference day in a collapsible `Plan to do today` section before the normal task buckets. Context menus on task rows can set the planned date to today, open a date picker for another date, or clear the plan.

## Consequences

Planning a task does not schedule notifications, affect overdue behavior, or create planner blocks by itself. The Home list is the primary surface for this lightweight intent.

Pinned tasks remain in the pinned section even when they have a planned date, preserving the existing priority of pinning. Planned tasks are removed from the normal active buckets while they appear in `Plan to do today` to avoid duplicate rows. Daily routines with stale or imported `plannedDate` values are ignored by the planned-today section and continue to use the daily routine section.

Backup, import, CloudKit sharing, CloudKit direct pull repair, draft persistence, and iCloud usage estimates should preserve `plannedDate`.
