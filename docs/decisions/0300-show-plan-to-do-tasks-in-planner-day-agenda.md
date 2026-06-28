# 0300 Show Plan-to-Do Tasks in Planner Day Agenda

Status: Accepted

Date: 2026-06-28

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0288 Open Planned Day Task List From Planner Headers](0288-open-planned-day-task-list-from-planner-headers.md), [0289 Filter Planner Calendar Layers](0289-filter-planner-calendar-layers.md)

## Context

Task creation and Task Details let users set a lightweight `Plan to do` date. Planner day headers also expose a planned-task list for a selected date.

Those two concepts used similar language but were not connected: a task planned for Monday from More Details appeared in Home's day plan but did not appear in Planner's Monday task list unless it also had a persisted Planner block or all-day Planner presentation item.

## Decision

Planner day agendas include active date-only `Plan to do` tasks for the selected date, presented with the all-day task portion of the agenda before timed Planner blocks.

This is presentation-only. It does not create a persisted `DayPlanBlockRecord`, does not place a timed calendar block, and does not change availability, deadline, reminder, recurrence, or completion semantics.

The day agenda excludes stale or priority-overridden planned-date rows: daily routines, completed one-off tasks, canceled one-off tasks, archived or snoozed tasks, and pinned tasks do not appear from `plannedDate` alone. If a task already appears through a visible all-day or timed Planner item for that day, the date-only `Plan to do` row is deduplicated.

Date-only planned rows follow the existing all-day task visibility filter, so hiding all-day tasks in Planner filters also hides these agenda rows.

## Consequences

Users who choose `Plan to do` Monday from Add More Details or Task Details can find that task in Planner's Monday planned-task list without needing to drag it onto the Planner.

The older rule from decision 0200 remains intact: planned dates are still lightweight planning hints and do not create stored Planner blocks.
