# 0123 — Keep disabled features out of iCloud usage

Date: 2026-08-09

## Symptom

Estimated iCloud Usage listed Goals, Events, and Emotions even though those production features were unavailable to the user.

## Root Cause

The usage card always rendered every stored model category. It did not apply the shared feature gates that already control the rest of the app's visible surfaces.

## Fix

The iCloud usage presentation now takes Places, Goals, Event/Emotion, and Notes availability explicitly. Each gated row is shown only when its feature is available on the current app variant.

## Prevention Rule

Every user-facing data summary must respect the same feature-availability policy as the feature's navigation and actions. Retained compatibility data may sync and count toward total storage without exposing a disabled feature as a visible category.

## Regression Safeguard

`SettingsSectionViewSupportTests.cloudUsageHidesCategoriesWhoseFeaturesAreUnavailable` and `cloudUsageShowsAvailableFeatureCategories` verify both sides of the gate. The matching scenario is recorded in `docs/scenarios/README.md`.
