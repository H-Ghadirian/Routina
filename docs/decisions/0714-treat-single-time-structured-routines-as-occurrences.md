# 0714 — Treat Single-Time Structured Routines as Occurrences

**Status:** Accepted
**Date:** 2026-09-03

## Refines

- [0002 — Define Exact-Time Routine Completion Semantics](0002-define-exact-time-routine-completion-semantics.md)
- [0003 — Resolve Exact-Time Missed Assumptions](0003-resolve-exact-time-missed-assumptions.md)
- [0412 — Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md)
- [0433 — Identify Subdaily History by Scheduled Occurrence](0433-identify-subdaily-history-by-scheduled-occurrence.md)
- [0615 — Group and Control Pending Notification Occurrences](0615-group-and-control-pending-notification-occurrences.md)

## Context

A fixed structured routine could contain one explicit clock time on each valid
day without an outer availability range. The recurrence generator produced the
right dates, but exact-occurrence classification required a range. After one
meeting was left unresolved, the task therefore remained overdue at the old
timestamp instead of exposing a missed occurrence and advancing to the next
date.

Notification reconciliation then compounded the classification error. Its
generic safety fallback moved a past exact trigger to one minute after each
reconciliation, so the same historical occurrence could repeatedly alert and
appear to move through the pending-notification list.

## Decision

A fixed structured recurrence with at most one occurrence per day and an
explicit occurrence time is an exact timed occurrence even when it has no
outer range. Once its close boundary passes, it remains an unresolved missed
occurrence while due status and future alerts advance to the next generated
occurrence. A range still supplies its explicit close boundary; a single time
without a range retains the established end-of-local-day close boundary.

Notification scheduling registers only occurrence dates later than the
reconciliation reference time. A stale explicit or exact trigger is discarded;
it is never translated into a one-minute retry. Untimed repeating reminders
may still roll forward to the next configured default reminder time.

Every queued occurrence stores its original scheduled timestamp. Notification
quick actions carry that timestamp back to the task lifecycle, so `Done`
resolves the occurrence that raised the alert, including after Snooze, rather
than whichever occurrence happens to be current when the action is handled.

Task Details presents the oldest unresolved exact occurrence as `Needs review`
with occurrence-specific `It happened`, `Missed`, and `Canceled` actions and
the next occurrence. The ordinary undifferentiated Done action is hidden while
that review card owns the primary decision.

Notification Settings calls the global clock value the default for untimed
repeating tasks, labels occurrence postponement as Snooze, uses a notification
icon for task groups, and summarizes each collapsed group by its next alert and
the number queued later.

## Consequences

- A biweekly Tuesday meeting left unresolved no longer stays red and overdue
  or generates a minute-by-minute notification loop.
- The missed meeting remains reviewable without blocking or rewriting the next
  meeting.
- Bounded rolling alerts can still produce several pending requests for one
  Advanced routine, but the collapsed group explains that they are future
  occurrences rather than repeated alerts for the same due time.
- A person who needs a meeting to close before the end of its day should use a
  Time block so the end time becomes the explicit close boundary.
