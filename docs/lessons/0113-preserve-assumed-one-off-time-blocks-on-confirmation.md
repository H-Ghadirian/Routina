# 0113 — Preserve assumed one-off time blocks on confirmation

Date: 2026-08-08

## Symptom

Confirming an auto-assumed one-off `Time block` recorded the current time and a
generic 30-minute duration. Mac `Done this day` therefore opened with an
unrelated interval, and Task Detail did not show the task's own scheduled
date/time range.

## Root Cause

The one-off confirmation reducer reused the normal manual-completion timestamp
path. It knew the occurrence was assumed but discarded the scheduled block
range before creating the completion log.

## Fix

Eligible assumed one-off time blocks now resolve a shared confirmation timing:
their end is the completion timestamp, their full range is the actual duration,
and the log marks the work as specific time. Task Detail also exposes the
one-off block as Schedule metadata.

## Prevention Rule

Whenever synthetic task state becomes recorded history, carry every semantic
field that distinguishes that synthetic occurrence into the persistence call;
never fall back to generic “now” defaults when the synthetic state already has
an exact interval.

## Regression Safeguard

`RoutineAssumedCompletionTests`, `TaskDetailFeatureCompletionTests`, and
Task Detail metadata presentation tests cover the interval derivation, the
persisted timestamp/duration/marker, and Schedule badge visibility. The
auto-assume scenario records the intended Mac `Done this day` initialization.
