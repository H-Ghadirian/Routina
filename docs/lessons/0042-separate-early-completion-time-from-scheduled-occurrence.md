# 0042 — Separate Early Completion Time From Scheduled Occurrence

Date: 2026-07-26

## Symptom

Task Detail showed an enabled Done button for an untimed monthly routine before its due date, but pressing it produced no visible or persisted change.

## Root Cause

Presentation guarded only against selecting a future calendar day, while the reducer and structured recurrence persistence required the next due occurrence to be at or before the completion timestamp. The model also had only one date serving as both actual completion evidence and recurrence occurrence identity.

## Fix

Task Detail now explicitly permits early completion for eligible untimed, single-occurrence scheduled routines. Completion history keeps the actual timestamp, while task and log fields persist the scheduled occurrence that the completion satisfied. Due-date calculation advances from that occurrence.

## Prevention Rule

When an action can resolve scheduled work at a different time from its occurrence, persist actual activity time and scheduled occurrence identity separately, and keep presentation and mutation eligibility driven by the same explicit capability.

## Regression Safeguard

`TaskDetailFeatureCompletionTests` covers an early monthly rent completion through Task Detail. `RoutineAdvancedRecurrenceTests` covers explicit early-completion permission, actual history time, scheduled occurrence identity, and the next fixed due date.
