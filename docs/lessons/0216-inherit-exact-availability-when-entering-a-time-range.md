# 0216 — Inherit exact availability when entering a time range

Date: 2026-08-20

## Symptom

Editing a task parsed with an exact availability such as 15:00 and changing it to `Time block` or `Available window` showed the generic 07:00–10:00 range. A reminder that was selected relative to the exact time could also lose its event context while the form changed modes.

## Root Cause

The timing-mode controls only toggled the explicit-time and range flags. They never copied the visible exact time into the range fields. One-off reminder event-date derivation also recognized only an exact time-of-day, not the start of a time range.

## Fix

Both platform forms now seed a newly entered range from the exact time and preserve the standard three-hour initial duration. One-off reminder event dates use the range start when a time range is active, keeping lead-time reminders anchored to the same event.

## Prevention Rule

When a form changes representation of the same scheduling intent, initialize the new representation from the value already visible to the person and keep related reminder calculations pointed at the resulting event anchor.

## Regression Safeguard

`TaskFormPresentationTests` covers the inherited range and one-off range event date. `RoutineRecurrenceDraftTests` exercises the edit-handler transition and verifies that a two-hour reminder remains unchanged.
