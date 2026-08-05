# 0079 — Keep guided metadata procedures reducer-owned

Date: 2026-08-05

## Symptom

The iOS Add missing Pressure data procedure could show no tasks even when
tasks had missing pressure. Its live query and direct view mutation also made
the card index unstable as a saved task disappeared from the query results.

## Root Cause

The SwiftUI view compared the stored pressure string with a handwritten
lowercase `"none"`, while the model's typed raw value is `"None"`. It also
owned the SwiftData query, save, and navigation state, so the render surface
and the mutation that invalidated its data set were coupled.

## Fix

The procedure now uses a reducer-owned SwiftData effect with
`RoutineTaskPressure.none.rawValue`, keeps immutable task-card state, and
advances only after a successful persisted pressure update. The iOS view is
presentation-only and excludes `None` from the available choices.

## Prevention Rule

Guided missing-data flows must use typed model values rather than handwritten
storage literals, and their fetches and mutations must run through reducer
dependencies. Do not let a SwiftUI query and local index both own a collection
whose membership changes during the same interaction.

## Regression Safeguard

`MissingPressureDataFeatureTests` verifies exact missing-pressure loading,
persistence and one-card advancement, rejection of `None`, and the absence of
SwiftData work or scrolling gestures in the iOS procedure view. The matching
scenario is recorded in `docs/scenarios/README.md`.
