# 0250 — Persist choice state at the workspace boundary

Date: 2026-08-26

## Symptom

Mac Planner returned to Calendar, Schedule, and Week after Routina relaunched,
and could lose the person's chosen header values when the Planner workspace was
recreated.

## Root Cause

The three selected values lived only in `@State` and `DayPlanPlannerState`, each
initialized from a hard-coded default. Their owner survived some nested Planner
rebuilds but had no persistence boundary for a new workspace instance or app
process.

## Fix

Mac Home now restores and saves one device-local Planner presentation preference
containing the Planner view, Calendar task view, and preferred range. Explicit
range selection persists through a callback at the planner-state boundary,
while adaptive width fallbacks do not invoke it.

## Prevention Rule

If a visible current-value choice is expected to survive recreation of its
workspace, give the long-lived workspace owner an explicit persistence boundary.
When a selected value also has an environment-driven effective fallback, persist
only deliberate preference changes, never the temporary effective value.

## Regression Safeguard

`DayPlanPlannerStateTests.macPlannerPresentationPreferencesPersistEveryChoiceAndDecodeOlderPayloads`
verifies storage and compatibility defaults.
`adaptivePlannerRangeFallbackDoesNotReplacePersistedPreferredRange` verifies
that only explicit range selection reaches persistence, and the Mac Planner
source contract verifies that Home restores and saves both other choices.
