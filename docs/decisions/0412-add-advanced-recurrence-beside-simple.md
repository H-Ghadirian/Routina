# 0412 Add Advanced Recurrence Beside Simple

Status: Accepted

Date: 2026-07-21

Refines: [0177 Separate Interval and Calendar Repeat Controls](0177-separate-interval-and-calendar-repeat-controls.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md), [0204 Avoid Duplicate Daily Repeat Choices](0204-avoid-duplicate-daily-repeat-choices.md)

## Context

The Simple recurrence editor intentionally offers a small Interval / Calendar model. It is efficient for ordinary routines, but it cannot express schedules such as every other Tuesday, every third Saturday, every two months on the first Friday, or medicine every six hours during a daily time window.

Replacing the Simple model would make common creation slower and risk changing existing stored schedules. Subdaily recurrence also cannot use the existing one-completion-per-day history and one-pending-notification assumptions.

## Decision

Routine and cadence-enabled Tracking forms offer `Simple` and `Advanced` recurrence models. Simple remains the default and keeps the existing Interval / Calendar controls and stored behavior unchanged.

Advanced recurrence stores a versioned structured rule beside the existing compatibility recurrence kind. It supports:

- Hourly, daily, weekly, monthly, and yearly frequencies with an every-N interval.
- A fixed start date and time-zone identity.
- Daily multiple times, weekly weekday selection, monthly day-of-month or ordinal-weekday patterns, and yearly month/day selection.
- Continuous hourly schedules or hourly schedules constrained to a daily start/end window.
- Never, on-date, and after-count ending conditions.

Advanced occurrences are generated from the rule's fixed start anchor. Completing an occurrence records that scheduled occurrence timestamp and does not shift later calendar occurrences. Advanced schedules with more than one occurrence per day keep separate same-day completion logs and become actionable again when the next occurrence is due. Existing Simple schedules and single-occurrence Advanced schedules retain day-level completion presentation.

Notifications keep a rolling bounded set of pending Advanced occurrence requests and are rebuilt after task changes or completion. Simple recurrence continues using the existing single-request notification path.

## Consequences

Existing tasks decode and behave exactly as before because the Advanced payload is optional and Simple remains the default editor.

The existing structured recurrence storage carries Advanced rules without adding a SwiftData schema field. Compatibility kind and interval values remain available to older grouping, sync, and display paths.

Advanced recurrence is deliberately a bounded product model rather than an unrestricted recurrence-language parser. New patterns should extend the versioned rule and generator while preserving old decoded versions.
