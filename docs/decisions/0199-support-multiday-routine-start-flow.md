# 0199 Support Multi-Day Routine Start Flow

Status: Accepted

Date: 2026-06-10

Supersedes: [0198 Support Multi-Day All-Day Routines](superseded/0198-support-multiday-all-day-routines.md)

Refines: [0093 Support All-Day Tasks Across Schedule Types](0093-support-all-day-routines.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md), [0179 Make Routine All Day an Availability Choice](0179-make-all-day-an-availability-choice.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md)

## Context

Routines should remain recurrence-driven. Adding fixed date availability to routines would make them behave like one-off todos with concrete date bounds.

Some routines still naturally last longer than one day. Travel is the motivating example, but the duration should not be tied to all-day availability. A travel routine might be all-day, timed, exact-time, or windowed; the lasting-multiple-days choice is a lifecycle choice.

## Decision

Routine forms keep date availability out of the routine flow. Exact date and date-window availability remain todo-only concepts.

Routine forms get an independent duration choice:

- `One day` is the default routine duration.
- `Multi-day` means the routine must be started before it can be finished.

For a multi-day routine, the task detail primary action is `Start` while the routine is idle. Pressing `Start` moves the routine into the ongoing/in-progress state. While ongoing, the primary action becomes `Done`; pressing `Done` records the completion and clears the ongoing state.

Time availability remains separate from duration. `Any time`, `At time`, `All-day`, and `Time window` describe when the routine is available on each recurrence occurrence; `One day` versus `Multi-day` describes whether the routine uses the start/finish lifecycle.

## Consequences

Multi-day routines do not create fixed date availability and do not create multi-day planner all-day spans from recurrence occurrences. Planner date spans remain driven by actual dated events, todo date availability, or one-day all-day routine occurrences.

Backup, import, CloudKit sharing, and CloudKit repair should preserve the duration mode while treating missing older payload values as one day.

Soft routines keep their ongoing lifecycle support. Multi-day routines use the same persisted ongoing state, but present the primary action as `Start` and then `Done`.
