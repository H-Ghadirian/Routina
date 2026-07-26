# 0030 — Gate all recurrence behavior behind effective cadence

Date: 2026-07-26

## Symptom

A repeating task with `Repeat type: None` could still inherit behavior from its stored one-day fallback recurrence. It could produce due or daily status, become unavailable after one completion on the same day, lose same-day completion logs during deduplication, show cadence-only form controls, or silently switch back to Interval when its Routine/Tracking purpose changed.

## Root Cause

The persisted cadence-enabled field was treated as a Tracking-only option in several paths. Date math, form transitions, Home presentation, and completion-log identity sometimes read the fallback recurrence rule directly instead of first checking whether the task had an effective cadence.

## Fix

Cadence-free tasks now short-circuit recurrence date math, daily classification, status badges, automatic occurrence generation, and notifications. Routine/Tracking changes preserve the selected `None` state, cadence-only form controls are hidden, and cadence-free completion identity uses timestamps so multiple same-day completions remain distinct.

## Prevention Rule

Before interpreting a repeating task's recurrence rule as a schedule or using calendar-day completion identity, require `usesEffectiveRoutineCadence`. The recurrence rule of a cadence-free task is storage compatibility data and must not create occurrences, pressure, classification, or deduplication behavior.

## Regression Safeguard

The cadence-free scenario is covered by `TaskFormPresentationTests`, `AddRoutineFeatureTests`, `RoutineDateMathTests`, `RoutineLogHistoryTests`, `HomeTaskRowActionPresentationTests`, `HomeTaskListFilteringTests`, and `NotificationCoordinatorTests`. These tests verify purpose-switch preservation, no due/daily presentation, immediate repeat completion, and distinct same-day history.
