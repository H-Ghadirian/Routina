# 0223 Support Multi-Day Calendar Repeats

Status: Accepted

Date: 2026-06-12

Refines: [0177 Separate Interval and Calendar Repeat Controls](0177-separate-interval-and-calendar-repeat-controls.md), [0184 Label Month-Day Fallbacks Explicitly](0184-label-month-day-fallbacks.md), [0204 Avoid Duplicate Daily Repeat Choices](0204-avoid-duplicate-daily-repeat-choices.md)

## Context

Calendar repeat creation only allowed one weekday or one month day at a time. That made common routines such as Monday/Wednesday/Friday workouts or bills due on multiple dates require separate routines even though they share the same behavior, timing, notes, and metadata.

## Decision

Add Routine calendar repeats let users select multiple weekdays or multiple month days at once.

Weekly and monthly recurrence rules preserve ordered selected day arrays while keeping the existing single weekday and month-day fields as compatibility fallbacks. Single-day calendar repeats continue to store compactly in the typed columns. Multi-day calendar repeats store the complete recurrence rule JSON alongside the compatibility first selected day, and date math chooses the next selected calendar occurrence.

Month-day selections keep the existing fallback behavior for days 29, 30, and 31: shorter months use their last valid day.

## Consequences

Users can model multi-day calendar routines as one routine instead of duplicates.

Existing single-day routines remain readable and writable without migration churn.

Editors that still expose a single calendar day can fall back to the first selected day until they adopt the multi-select control.
