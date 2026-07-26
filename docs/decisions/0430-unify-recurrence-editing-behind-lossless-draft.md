# 0430 Unify Recurrence Editing Behind a Lossless Draft

Status: Accepted

Date: 2026-07-26

Refines: [0177 Separate Interval and Calendar Repeat Controls](0177-separate-interval-and-calendar-repeat-controls.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md), [0412 Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md), [0421 Support Cadence-Free Repeating Routines](0421-support-cadence-free-repeating-routines.md)

## Context

The Simple / Advanced choice asks users to select an implementation model before describing their schedule. It also duplicates form controls and makes capabilities appear mutually exclusive even though recurrence is naturally composed from cadence, frequency, selectors, timing, start, and end conditions.

Routina already has two persistence/runtime representations with important semantic differences. Compact interval rules roll from completion, compact calendar rules represent ordinary fixed calendar recurrence, and Advanced rules use a fixed start anchor with richer occurrence generation. Replacing those representations while redesigning the form would create unnecessary migration, sync, notification, and history risk.

## Decision

Recurrence editing will converge on one progressively disclosed composer rather than presenting Simple and Advanced as user-facing models.

The form-domain boundary is `RoutineRecurrenceDraft`, which represents:

- Cadence-free, item-runout, after-completion, and scheduled recurrence intent.
- Hourly, daily, weekly, monthly, and yearly frequency plus every-N intervals.
- Independent availability timing for compact rules, including exact time and time windows with their availability or scheduled-block role.
- Fixed starts, selected weekdays and month dates, ordinal monthly patterns, yearly selectors, multiple occurrence times, hourly daily windows, time-zone identity, and end conditions.

The draft translates compact existing rules and every supported structured rule without losing their recurrence intent. Compact storage remains preferred whenever it can represent the draft completely. Fixed-anchor or otherwise structured schedules continue using the versioned Advanced payload. Cadence-free and item-runout modes retain their compatibility interval values without exposing those values as the user's recurrence model.

Unsupported combinations must produce an explicit draft validation issue rather than silently discard fields. In particular, the existing runtime cannot yet combine structured fixed-anchor recurrence with the outer compact-rule availability window; the future composer must keep that combination unavailable until the structured runtime supports it.

Availability remains a scheduling dimension independent of cadence. One-time Date window, multi-day routine duration, and task planning remain outside the recurrence draft. A scheduled recurrence's start/end condition is its active range, not a replacement for one-time date availability.

The rollout is staged. The lossless draft and adapters land first while the current Simple / Advanced controls remain visible. The visible selector is removed only after the unified composer can edit every supported field and its save path is protected by round-trip and occurrence tests.

## Consequences

- The eventual UI can reveal power based on the selected frequency and optional modules instead of asking users to choose a complexity level.
- Current task storage, sync compatibility fields, occurrence history, reminders, and recurrence engines do not require migration.
- Add Task, Edit Task, and shared form presentation can inspect the same recurrence draft during the transition.
- New recurrence capabilities must extend the draft and its translation tests before becoming visible in the composer.
- Runtime capability gaps become explicit validation work instead of hidden data loss.
