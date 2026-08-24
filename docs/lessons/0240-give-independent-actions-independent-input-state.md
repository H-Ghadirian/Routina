# 0240 — Give independent actions independent input state

Date: 2026-08-24

## Symptom

Mac Task Detail placed Log, Countdown, and Count up beside one duration input.
People could not tell whether the selected duration would record Actual time,
start Focus, or affect Count up.

## Root Cause

Related Effort actions reused one picker value and one remembered preference.
The shared implementation state became a visible product relationship even
though Actual time and Focus have different meanings and persistence.

## Fix

Expanded Effort now gives Actual time and Focus separate labeled control areas,
defaults, presets, and remembered preferences. Focus first chooses Countdown or
Count up; only Countdown reveals its duration input. Running, blocked, Sleep,
and Away states replace Focus start controls with status while leaving Actual
time independently actionable.

## Prevention Rule

When actions produce different records or answer different questions, give
each action its own input state and remembered choice. Do not place an input
beside an action that ignores it, even when the actions share a broader group.

## Regression Safeguard

`TaskDetailTimeSpentPresentationTests` protects independent defaults and
clamping. `TaskDetailSharedViewSupportTests` protects separate preference keys,
presets, labels, modes, and action ownership.

See [Decision 0655](../decisions/0655-separate-mac-task-detail-actual-time-and-focus-controls.md)
and [Regression Scenarios](../scenarios/README.md#mac-task-detail-separates-actual-time-and-focus-inputs).
