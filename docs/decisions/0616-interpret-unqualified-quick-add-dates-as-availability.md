# 0616: Interpret Unqualified Quick Add Dates as Availability

Status: Accepted

Date: 2026-08-20

Refines: [0074 Parse Mac Add Task Title](0074-parse-mac-add-task-title.md), [0185 Limit Exact-Date Reminders to Todos](0185-limit-exact-reminders-to-todos.md), [0197 Separate Todo Date and Time Availability](0197-separate-todo-date-and-time-availability.md), [0315 Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md)

## Context

Quick Add treated every recognized one-off date and time as both a deadline and a reminder. An appointment-style phrase such as `Physiotherapist Tuesday, 25 August 15:00` therefore left the task with `Any date` / `Any time` availability while silently creating two stronger commitments.

Routina already models availability, deadline, and reminder independently. An unqualified appointment date describes when the task happens or becomes actionable; it does not establish that the task becomes overdue then, and it does not grant permission to schedule a notification.

## Decision

For one-off Smart Add and Quick Add input:

- An unqualified date, optionally followed by a time, becomes todo availability. A single date selects `At date`; an accompanying time also selects `At time`.
- The words `due` and `by` explicitly create a deadline instead. A deadline does not also create a separate `reminderAt` value.
- Parsing never infers a reminder merely because a date or time exists.
- When Mac toolbar Quick Add recognizes an exact availability date and time, its pre-save preview offers `No reminder`, `1 hour before`, `2 hours before`, `1 day before`, and `Custom date/time`. `No reminder` is the default.
- Add and Edit Task relative-reminder choices use exact todo availability as their event time. Deadline remains the fallback reference when no exact availability event exists.

## Consequences

- Appointment-style capture creates a Planner-visible exact availability block and the same-day planning projection without making the task overdue.
- A reminder is always a visible user choice.
- People can still express a commitment explicitly with phrases such as `due Friday` or `by 25 August 15:00`.
- Deadline and availability may coexist when they mean different things, such as an appointment at 15:00 with paperwork due at 18:00. Setting both to the same instant is usually redundant except for deadline status and grouping.
