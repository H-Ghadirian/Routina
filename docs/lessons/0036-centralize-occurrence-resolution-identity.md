# 0036 — Centralize occurrence resolution identity

Date: 2026-07-26

## Symptom

Subdaily completions could coexist, but missed and canceled actions and some optimistic UI checks still treated every log on the same date as one resolution. One occurrence could hide, replace, or remove another, and multiple daily times could not safely use a shared availability range.

## Root Cause

Occurrence identity was an implicit comparison choice repeated across date math, persistence, Home, and Task Detail. Timestamp-aware completion code had been added for Advanced recurrence, but day-based helpers remained in sibling lifecycle paths.

## Fix

A shared `RoutineOccurrenceIdentity` policy now defines timestamp-scoped versus day-scoped resolution. Subdaily completion, missed, canceled, deduplication, optimistic-state, and undo paths use it consistently. Structured daily schedules with several occurrence times preserve each generated timestamp while an outer range supplies the shared daily availability boundary.

## Prevention Rule

Never compare routine resolution dates directly in a lifecycle or presentation path. Route the comparison through the shared occurrence-identity policy, and test every terminal kind when a recurrence can occur more than once per day.

## Regression Safeguard

`RoutineAdvancedRecurrenceTests` verifies separate same-day occurrence timestamps and independent missed/canceled resolution. `RoutineRecurrenceDraftTests` verifies that multiple daily times compose with an outer range while hourly recurrence still reports its distinct window-authority conflict. Decision [0433](../decisions/0433-identify-subdaily-history-by-scheduled-occurrence.md) defines the durable contract.
