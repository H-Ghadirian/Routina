# 0217 — Remember picker state separately from session history

Date: 2026-08-20

## Symptom

The Mac Focus sheet could restore a duration from a started Focus session, but
a duration selected and then canceled was lost. The next sheet opening did not
show which duration had been chosen last.

## Root Cause

The picker treated synchronized Focus-session history as its only source of
recency. Session history records started activity, not every local picker
choice, so it could not represent an abandoned setup or provide an explicit
last-choice indicator.

## Fix

The picker now stores its selected duration in device-local preferences,
reuses it on the next opening, and labels it Last choice. Attributed session
history remains the fallback for installations without a saved picker value.

## Prevention Rule

When a UI choice is meaningful before a domain record is created, persist the
choice at the UI boundary and keep it separate from history that represents
completed actions.

## Regression Safeguard

FocusSessionStartDefaultsTests.rememberedDurationOverridesHistoryAndSurvivesPersistence
verifies storage, precedence over session history, and the no-history fallback.
PerformanceRegressionTests.testMacFocusStartUsesOneRecallingSheet verifies the
Mac sheet exposes and saves the last choice.
