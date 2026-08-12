# 0149 — Gate iOS task-row appearance controls

Date: 2026-08-12

## Symptom

iOS Settings -> Appearance showed Task Row `Goals` and `Places` toggles while
their owning features were disabled. The preview and visible-field count also
continued to include those unavailable concepts.

## Root Cause

The shared appearance-field model already supported Goal and Places
availability, but the iOS settings screen iterated every field directly and
did not pass feature availability into its preview.

## Fix

iOS Appearance now derives its Task Row controls, preview, and visible-field
summary from the existing Goal and Places availability gate. Persisted
visibility preferences remain unchanged for restoration after re-enabling a
feature.

## Prevention Rule

When a feature is gated, every configuration surface and its preview must use
the same availability-filtered field model; do not iterate the complete field
catalog directly. See [0039](0039-gate-appearance-controls-with-feature-availability.md).

## Regression Safeguard

`SettingsAppearanceFeatureAvailabilityTests` verifies the iOS settings screen
and preview receive both Goal and Places availability, while
`HomeTaskListFilteringTests.appearanceFieldsRespectFeatureAvailability`
protects the shared field model.
