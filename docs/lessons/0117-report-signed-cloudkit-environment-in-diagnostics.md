# 0117 — Report signed CloudKit environment in diagnostics

Date: 2026-08-09

## Symptom

After reinstalling an iOS production app, the configured `Production (iCloud)` data mode and production container could appear correct even though the restored data differed from another installation's data.

## Root Cause

The Support & About diagnostics showed configuration values, not the `com.apple.developer.icloud-container-environment` entitlement embedded in the running executable's code signature. A shared container identifier does not establish whether a build accesses CloudKit Development or Production.

## Fix

Added a `Signed CloudKit Environment` diagnostic row on iOS and macOS. It reads the running executable's entitlement with `SecTaskCopyValueForEntitlement` and keeps absent or unexpected values explicit.

## Prevention Rule

When diagnosing a signed platform capability, display the value read from the running binary's signed entitlement separately from app configuration values that only express intent.

## Regression Safeguard

`Tests/Shared/AppEnvironmentTests.swift` verifies entitlement-value formatting and absent/invalid handling. `Tests/Shared/SettingsFeatureDependencyTests.swift` verifies that the signed value reaches Settings diagnostics. The matching regression scenario is recorded in `docs/scenarios/README.md`.
