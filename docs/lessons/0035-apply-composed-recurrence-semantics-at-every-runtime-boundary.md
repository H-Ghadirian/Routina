# 0035 — Apply composed recurrence semantics at every runtime boundary

Date: 2026-07-26

## Symptom

The form rejected a valid modular request such as “every two weeks on Monday and Wednesday, available from 18:00 to 21:00,” even though the recurrence payload could store both parts. Simply allowing save would have left different screens using different times.

## Root Cause

Structured recurrence generation and time availability had independent data representation but not a shared effective-occurrence contract. Date math, missed tracking, notifications, and Planner paths consumed the Advanced generator's internal anchor timestamp directly, while validation hid the inconsistency by rejecting an outer window.

## Fix

Fixed date-based structured recurrence now resolves each generated date through its outer time range. The range start is the effective occurrence timestamp and the range end closes actionability. Exact missed tracking, completion targeting, notifications, Planner placement, summaries, form resolution, storage, and time-zone-aware date math use that same contract. Ambiguous hourly and multiple-times-per-day combinations receive precise validation errors.

## Prevention Rule

When two task behavior modules compose, define one domain-level effective value and route every runtime consumer through it. Do not treat form validation as a substitute for aligning date math, lifecycle, history, notifications, planning, persistence, and sync semantics.

## Regression Safeguard

`RoutineRecurrenceDraftTests`, `RoutineDateMathTests`, `NotificationCoordinatorTests`, `DayPlanPlannerStateTests`, `RoutineAdvancedRecurrenceTests`, and `CloudKitDirectPullRecurrenceTests` cover resolution, round-trip preservation, actionability, missed occurrences, notification dates, Planner blocks, structured storage, and direct-pull sync. Decision [0432](../decisions/0432-compose-fixed-recurrence-with-availability-windows.md) and the `Fixed Recurrence Composes With Time Availability` scenario define the durable contract.
