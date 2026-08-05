# 0080 — Exclude finished one-off tasks from metadata procedures

Date: 2026-08-05

## Symptom

The iOS Add missing Pressure procedure could show cards tagged `Done`, including
completed one-off tasks that no longer needed a pressure value.

## Root Cause

The procedure fetched every task whose pressure was `None` without applying the
one-off task lifecycle. Completed and canceled one-offs therefore satisfied the
metadata-only predicate.

## Fix

The guided-procedure fetch now includes every repeating task with missing
pressure and includes a one-off task only while it has neither `lastDone` nor
`canceledAt`. Its save effect applies the same eligibility rule before writing.
The completion copy now correctly refers to eligible tasks.

## Prevention Rule

Whenever a guided metadata procedure selects tasks by a missing field, combine
that field rule with the task lifecycle rule. Do not ask users to backfill
metadata on completed or canceled one-off tasks.

## Regression Safeguard

`MissingPressureDataFeatureTests` verifies that repeating and unfinished
one-off tasks with missing pressure load in title order, while completed and
canceled one-offs are excluded. The corresponding scenario is recorded in
`docs/scenarios/README.md`.
