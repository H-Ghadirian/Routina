# 0289 — Inject the date that seeds editor state

Date: 2026-09-03

## Symptom

Add Task reducer tests produced different initial recurrence state depending on
the wall clock, and platform presentation paths could seed weekday, month day,
and advanced-recurrence start values from different instants.

## Root Cause

`AddRoutineScheduleState` used `Date()` and `Calendar.current` in stored-property
defaults. Parent features injected a clock for reducer effects, but child-state
construction bypassed that dependency.

## Fix

`AddRoutineFeature.State` accepts an optional reference date and calendar and
uses them to seed every date-derived recurrence field. Both platform Home
features, presentation routers, and direct state builders pass their injected
clock and calendar.

## Prevention Rule

Any state initialized from “now” must accept the owning feature's clock and
calendar. Do not hide wall-clock reads in reducer child-state defaults.

## Regression Safeguard

Add Task and Home presentation tests construct expected child state with fixed
dates and calendars, covering every platform router.
