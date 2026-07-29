# 0064 — Gate global entry points with feature availability

Date: 2026-07-29

## Symptom

The iOS bottom-bar New sheet still showed Event, Emotion, Goal, and Going to
sleep while their related Beta Experiments were disabled.

## Root Cause

The New sheet maintained its own partial filter. It honored Notes, Places,
Away, and a dedicated Sleep shortcut preference, but did not derive all rows
from the app's feature-availability settings.

## Fix

The New sheet now filters Event, Emotion, Goal, and Sleep using their Beta
Experiment settings. Sleep additionally requires its parent Away feature and
honors its dedicated New-sheet preference. Direct action routing and modal
presentation repeat the same guards, and iOS Beta Experiments now exposes the
Event/Emotion setting.

## Prevention Rule

When an optional feature gains a global entry point, derive both the visible
control and its action routing from the same availability source used by
navigation, filters, and reports. A hidden destination is not fully gated while
another global creation surface still opens it.

## Regression Safeguard

`IOSNewTabActionAvailabilityTests` verifies that the iOS New sheet filters and
guards every experiment-backed action and that the Event/Emotion toggle is
available in iOS Beta Experiments. The expected behavior is also recorded in
`docs/scenarios/README.md`.
