# 0444 — Log Completion Duration Without a Specific Time

Status: Accepted

Date: 2026-07-27

Refines: [0036 Treat Completion Times as Planner Finish Times](0036-treat-completion-times-as-planner-finish-times.md), [0435 Edit Calendar List Done Times From Mac Task Detail](0435-edit-calendar-list-done-times-from-mac-task-detail.md), [0441 Enter Custom Calendar List Done Durations](0441-enter-custom-calendar-list-done-durations.md)

## Context

The Mac Planner Calendar `List` Done editor originally modeled completed work
as one continuous interval. That works when the user knows one start time and
one duration, but it invents a misleading interval when a routine was completed
in several short sessions across the day.

The completion timestamp is also the identity and calendar evidence for the
recorded occurrence. Removing it would make the completion disappear from
history, Stats, recurrence resolution, and the selected Calendar List day.

## Decision

The Mac `Done this day` editor offers `Specific time` and `No specific time`
under `When`.

With `Specific time`, the existing behavior remains: the user selects a start,
the duration must finish within the selected day, and Save stores the completion
timestamp as start plus duration.

With `No specific time`, the user records one total whole-minute duration for
the day without claiming that the work happened in one interval. Save updates
the exact selected completion's duration and preserves its existing completion
timestamp as occurrence identity and calendar evidence.

`RoutineLog` stores an optional `hasSpecificWorkTime` marker. A missing marker
keeps legacy behavior and is interpreted as specific time; an explicit `false`
round-trips through SwiftData, CloudKit direct pull, detached copies, cache
signatures, and backup/import. Calendar List presents an unplanned duration-only
completion as `No specific time` with its total duration.

Planner blocks, planned rows, recurrence, availability, reminders, estimates,
other occurrences, and other days remain unchanged. Explicitly moving a
completed timeline occurrence establishes a specific time again.

## Consequences

- Split-session work can keep an accurate daily total without a fabricated
  start/end range.
- Completion identity and date-based behavior continue to use the existing
  timestamp.
- Existing logs remain backward compatible without a destructive migration.
- Specific-time corrections keep their prior finish-time semantics.
