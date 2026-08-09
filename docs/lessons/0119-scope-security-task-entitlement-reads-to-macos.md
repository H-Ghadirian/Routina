# 0119 — Scope Security task entitlement reads to macOS

Date: 2026-08-09

## Symptom

The iOS production build failed to compile after adding a diagnostic that read the running executable's entitlement with `SecTaskCreateFromSelf`.

## Root Cause

`SecTaskCreateFromSelf` and `SecTaskCopyValueForEntitlement` are public macOS Security APIs; they are not available to the iOS SDK. An iOS distribution app also cannot reliably recover the signed entitlement from a provisioning profile.

## Fix

Conditionally compile the signed-entitlement read on macOS and report `Unavailable on iOS` on the iOS diagnostic surface.

## Prevention Rule

Verify public API availability against every supported platform before placing an entitlement, process, or code-signature diagnostic in shared code. Never replace an unavailable signed value with an inferred configuration value.

## Regression Safeguard

The iOS production build validates the iOS compilation branch, while the macOS build and `AppEnvironmentTests` retain the signed-entitlement formatting coverage. The updated cross-platform expectation is documented in `docs/scenarios/README.md`.
