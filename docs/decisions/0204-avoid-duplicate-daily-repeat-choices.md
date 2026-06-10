# 0204 Avoid Duplicate Daily Repeat Choices

Status: Accepted

Date: 2026-06-10

Refines: [0177 Separate Interval and Calendar Repeat Controls](0177-separate-interval-and-calendar-repeat-controls.md), [0199 Support Multi-Day Routine Start Flow](0199-support-multiday-routine-start-flow.md)

## Context

The routine repeat form exposed both `Interval -> Every day` and `Calendar -> Daily`. Those choices describe the same daily cadence, so keeping both made the calendar pattern selector noisier without adding a distinct scheduling model.

Multi-day routines also use a start-finish lifecycle. Pairing that lifecycle with an interval of every 1 day creates an awkward cadence where a routine can span multiple days while immediately recurring daily.

## Decision

Routine forms keep `Interval -> Every day` as the daily repeat path.

When `Calendar` is selected, the calendar pattern control offers only `Weekday` and `Month day`. Existing stored `dailyTime` recurrence rules remain valid for compatibility, but form controls should treat them as the interval daily path unless the user changes them.

When a routine is `Multi-day` and uses a day-based interval, the minimum interval value is 2 days. Switching a daily calendar recurrence to multi-day normalizes it to an interval recurrence before applying that minimum.

## Consequences

The form has one daily repeat choice instead of two.

Multi-day routines cannot be saved as an every-1-day interval through UI state, drafts, or edit-save request construction.

Persistence and sync can continue reading older `dailyTime` recurrence rules.
