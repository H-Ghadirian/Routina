# 0185: Limit Exact-Date Reminders to Todos

- **Status:** Accepted
- **Date:** 2026-06-07
- **Refines:** [0183](0183-support-todo-availability-time-windows.md), [0178](0178-make-recurrence-availability-independent.md)

## Context

Task forms offered `Set reminder` as an exact date/time picker for both todos and routines. That made sense for one-off todos, where the user may want one notification at a specific moment. It was confusing for routines because routines already have cadence and availability, so a single absolute reminder date reads like a one-time exception instead of a repeat-aware notification rule.

Routine notifications still exist through global notification settings, due dates, exact availability times, and snooze/not-today flows. Those are schedule-relative. The form-level exact date/time reminder is different and should not be used for repeat routines.

## Decision

Exact date/time reminders in task forms are supported only for todos (`scheduleMode == .oneOff`).

- Todo forms continue to show `Set reminder`.
- Routine forms hide the exact reminder control.
- Switching a draft from Todo to Routine clears the draft reminder.
- Add/edit save requests write `reminderAt` only for one-off todos.
- Notification scheduling ignores `reminderAt` on routines, falling back to cadence/availability-based routine notifications.

Future routine reminder work should use schedule-relative options, such as at availability start or before a recurring due occurrence, rather than a one-time absolute date picker.

## Consequences

The scheduling form has fewer overlapping time concepts. Existing routine records that still have a stored `reminderAt` no longer treat it as a custom exact trigger, and future form saves clear that value for routines.
