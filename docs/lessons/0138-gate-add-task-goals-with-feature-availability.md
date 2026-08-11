# 0138 — Gate Add Task goals with feature availability

Date: 2026-08-11

## Symptom

The iOS Add Task form offered a Goal option while Settings `Show Goals tab` was disabled.

## Root Cause

The compact form filtered Places and Notes by their feature preferences but omitted the equivalent Goals filter. Its creation-mode default therefore made Goals available through the Add Task flow.

## Fix

The iOS task-form root now reads `appSettingGoalsTabEnabled` and filters the Goal compact section before either the visible form or Add details menu is built. macOS already applies the same gate.

## Prevention Rule

Every optional-feature entry point, including form defaults and progressive-disclosure menus, must apply that feature's shared availability preference.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.addTaskHidesGoalsWhenTheGoalsFeatureIsDisabled` verifies the setting and Goal-specific section filter remain in the iOS form.
