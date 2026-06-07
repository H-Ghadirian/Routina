# 0177: Separate Interval and Calendar Repeat Controls

## Status

Accepted

## Date

2026-06-07

Refines recurrence form presentation for routine creation and editing.

## Context

The repeat cadence control presented `Interval`, `Daily`, `Weekday`, and `Month day` in one segmented picker. When `Interval` was selected, a second unit picker offered `Day`, `Week`, and `Month`.

That made `Weekday` or `Month day` in the top row feel too similar to `Week` or `Month` in the lower interval unit row, even though they represent different scheduling models.

## Decision

Routine forms first ask for repeat type:

- `Interval`: repeat after an elapsed duration.
- `Calendar`: repeat on a calendar pattern.

When `Calendar` is selected, the form reveals a second calendar pattern control with `Daily`, `Weekday`, and `Month day`.

The stored `RoutineRecurrenceRule.Kind` remains unchanged as `intervalDays`, `dailyTime`, `weekly`, and `monthlyDay`. The `Interval / Calendar` split is a UI-facing grouping over those stored kinds.

## Consequences

- Users choose between duration-based and calendar-based repeat models before choosing details.
- The interval unit picker can keep `Day`, `Week`, and `Month` without colliding with calendar pattern labels.
- Code that persists or evaluates recurrence rules should continue using `RoutineRecurrenceRule.Kind`; form code should use the UI-facing repeat basis when rendering controls.
