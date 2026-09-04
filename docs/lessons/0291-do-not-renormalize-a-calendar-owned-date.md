# 0291 — Do not renormalize a calendar-owned date

Date: 2026-09-03

## Symptom

Planning a task could persist the preceding UTC date when the feature calendar
and the process's current calendar used different time zones.

## Root Cause

The command layer normalized the selected day with its injected calendar, then
the persistence effect passed that already normalized value through a model
helper that used `Calendar.current`. The second normalization shifted the
instant.

## Fix

The persistence effect now stores the command's normalized `plannedDate`
directly. It does not reinterpret the owning calendar's day boundary.

## Prevention Rule

Normalize a date-only value exactly once at the boundary that owns the calendar
semantics. Downstream persistence must treat that value as authoritative.

## Regression Safeguard

`HomeFeatureTests.planTask_refreshesDisplayPlannedDateAndPersists` uses an
explicit test calendar and asserts both reducer state and the persisted model
retain the same normalized instant.
