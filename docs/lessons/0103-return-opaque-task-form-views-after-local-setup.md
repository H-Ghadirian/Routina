# 0103 — Return opaque task-form views after local setup

Date: 2026-08-08

## Symptom

The macOS app failed to build after the task-form performance update with an opaque-return-type compiler error in `TaskFormContent.identityCard`.

## Root Cause

The computed property gained a local parsed-draft constant but did not add an explicit `return` before constructing its `some View` value.

## Fix

`identityCard` now explicitly returns `TaskFormMacIdentityCard` after preparing the one-per-render parsed draft.

## Prevention Rule

When a computed property returning `some View` performs local setup without `@ViewBuilder`, explicitly return the final view expression.

## Regression Safeguard

The macOS performance regression source check requires the explicit return, and the macOS build compiles the affected view.
