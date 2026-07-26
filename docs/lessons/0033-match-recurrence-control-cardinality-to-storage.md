# 0033 — Match recurrence control cardinality to storage

Date: 2026-07-26

## Symptom

Routina could store several selected weekdays or monthly dates, but iOS Simple recurrence and Advanced monthly recurrence exposed only one value. Users could not create or fully edit schedules that the recurrence model already supported. Selecting several adaptive month dates could also produce duplicate Advanced occurrences when those dates resolved to the same last day of a shorter month.

## Root Cause

Each form surface implemented its own recurrence control, and some of those controls were still bound to scalar compatibility fields instead of the structured arrays. The Advanced generator also treated configured month-day values as distinct after clamping them to the target month's valid day range.

## Fix

Simple and Advanced recurrence now share multi-select weekday and month-day controls across iOS and macOS Add/Edit surfaces. Days 29–31 have an orange adaptive-date indicator and nearby explanation. Advanced monthly and yearly candidate generation deduplicates timestamps after applying the shorter-month fallback.

## Prevention Rule

When durable storage supports multiple values, every create and edit surface must bind to that structured collection; scalar compatibility fields are persistence fallbacks, not editor state. Any calendar normalization that can map several configured values to one timestamp must deduplicate after normalization.

## Regression Safeguard

`RecurrenceSelectionPolicyTests` protects multi-selection, ordering, valid-range cleanup, last-selection retention, and adaptive-day classification. `RoutineAdvancedRecurrenceTests.multipleMonthlyDatesStayDistinctAndAdaptiveFallbacksDoNotDuplicate` protects multi-date generation and shorter-month deduplication. The `Editing Calendar Routines Preserves All Selected Days` scenario covers cross-platform creation and editing.
