# 0084 — Reject neutral values in shared guided reviews

Date: 2026-08-06

## Symptom

After Pressure and Thinking needed began sharing their guided-review reducer,
a neutral `None` value could start a save and advance the card.

## Root Cause

The generalized reducer checked that a selected value belonged to its field,
but did not preserve Pressure's former guard that rejects its neutral value.

## Fix

Guided values now expose whether they are neutral, and the reducer rejects a
neutral or wrong-field value before setting save state or accessing SwiftData.

## Prevention Rule

When parameterizing a reducer over optional metadata, keep each field's
eligibility and non-neutral selection rules explicit at the shared action
boundary; matching the field alone is insufficient.

## Regression Safeguard

`MissingPressureDataFeatureTests` and
`MissingThinkingNeededDataFeatureTests` verify that neutral and wrong-field
selections neither save nor advance a card.
