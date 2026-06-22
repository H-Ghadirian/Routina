# 0266 Show Calendar Routines in Plan Today

Status: Accepted

Date: 2026-06-22

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0202 Nest Daily Routines Under Mac Plan Today](0202-nest-daily-routines-under-mac-plan-today.md), [0247 Make Mac Daily Routine Grouping Optional](0247-make-mac-daily-routine-grouping-optional.md)

## Context

Calendar-based routines such as `Every Monday` and `Every 15th` express that the task belongs to a named calendar day. Users expect those routines to appear in today's working plan when the configured weekday or month day is today, even if they did not manually assign a planned date.

Rolling interval routines such as `Every 7 days` or `Every 30 days` are different. They express cadence and pressure relative to an anchor rather than a named date, so automatically treating them as planned today would blur the difference between due state and planning intent.

## Decision

Home `Plan to do today` includes active unpinned non-daily routines with fixed calendar recurrence when their configured occurrence falls on the current reference day.

This applies to weekly and monthly-day calendar routines, including exact-time and time-window variants. It does not apply to rolling interval routines. Daily routines continue to join the today area through the existing daily-routine path.

Scheduled calendar routines are folded into the existing planned-today task group rather than creating a separate visible or internal scheduled-today group. If a non-daily routine has an explicit `plannedDate`, that explicit plan controls planned-today membership.

Exact-time and time-window completion availability remains unchanged: a routine can be visible in `Plan to do today` before its time arrives, while `Mark Done` follows the existing timing rules.

## Consequences

`Plan to do today` better matches the user's calendar-day expectation without changing recurrence storage, notifications, completion timing, or planner block creation.

Manual ordering reuses the existing `plannedToday` bucket for calendar routines that appear automatically in the today section.
