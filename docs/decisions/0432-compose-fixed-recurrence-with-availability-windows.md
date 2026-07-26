# 0432 — Compose Fixed Recurrence With Availability Windows

Status: Accepted

Date: 2026-07-26

Refines: [0431 Present One Progressive Recurrence Composer](0431-present-one-progressive-recurrence-composer.md), [0430 Unify Recurrence Editing Behind a Lossless Draft](0430-unify-recurrence-editing-behind-lossless-draft.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md), [0009 Support Routine Time Ranges](0009-support-routine-time-ranges.md), [0375 Split Time Blocks From Available Windows](0375-split-time-blocks-from-available-windows.md)

Refined by: [0433 Identify Subdaily History by Scheduled Occurrence](0433-identify-subdaily-history-by-scheduled-occurrence.md)

## Context

The unified recurrence draft could describe an every-N fixed schedule and a separate time availability window, and structured recurrence storage could encode both. Decision 0430 nevertheless required the form to reject that combination because runtime consumers interpreted only the Advanced occurrence timestamp. Removing only the validation would have produced inconsistent due dates, completion windows, missed history, notifications, and Planner blocks.

The common user intent is modular: for example, repeat every two weeks on Monday and Wednesday, and make each occurrence available from 18:00 to 21:00.

## Decision

Fixed date-based structured recurrence may be combined with one time availability range when the recurrence produces at most one occurrence per calendar day.

The two modules have separate authority:

- Structured recurrence determines which calendar dates contain occurrences, including interval phase, weekdays, month dates, yearly dates, start, time zone, and end conditions.
- The outer time range determines the effective occurrence start and end on each selected date.
- `Available window` makes the occurrence actionable only within the range and stays out of Planner Schedule by default.
- `Time block` uses the same actionability range and may create the default full-range Planner block.

Due, completion, missed-occurrence, notification, display-day, and Planner calculations must use the range start as the effective occurrence timestamp and the range end as its closing boundary. The original structured recurrence remains authoritative and is serialized together with the range; compatibility columns must not replace or narrow it.

Hourly recurrence and daily recurrence with several occurrence times do not accept one outer availability window. Existing completion and missed-resolution identity is day-based for this behavior and cannot distinguish several windows on one day. The editor keeps those fields visible and reports the specific conflict instead of discarding either module.

## Consequences

- Users can compose every-N weekly, monthly, ordinal-monthly, and yearly schedules with either an available window or a scheduled time block.
- Home, Task Detail, Planner, and notifications share the same effective occurrence boundary.
- A structured availability window participates in exact timed missed-resolution behavior.
- Storage and CloudKit keep the complete structured rule, time range, and time-range role without a schema migration.
- Supporting an outer range for subdaily recurrence requires occurrence-level identity that is finer than a calendar day.
