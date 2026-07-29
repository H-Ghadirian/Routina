# 0067 — Match New-action presentation to cardinality

Date: 2026-07-29

## Symptom

When feature settings left Task as the only available iOS New action, tapping
New opened a sheet containing a single Task row instead of opening task
creation.

## Root Cause

The New-tab handler presented its chooser unconditionally. Availability was
used to filter the rows inside the sheet but not to decide whether a choice
surface was needed.

## Fix

The handler now derives available actions first. It routes one action directly,
opens the chooser for two or more actions, and safely does nothing for an empty
set. Destination-level availability guards remain in place.

## Prevention Rule

Before presenting a selection surface, evaluate the cardinality of its current
feature-gated destinations. A single destination should route directly unless
the intermediate surface provides additional required context.

## Regression Safeguard

`IOSNewTabActionAvailabilityTests` verifies that the New-tab handler routes a
single available action through the guarded destination handler and presents
the chooser only when multiple actions are available.
