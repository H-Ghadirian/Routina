# 0115 — Declare both HealthKit purpose strings

Date: 2026-08-09

## Symptom

App Store Connect rejected an iOS upload with server error 90683 because the production `Info.plist` did not contain `NSHealthUpdateUsageDescription`.

## Root Cause

Routina correctly declared its then-current read-only HealthKit purpose with `NSHealthShareUsageDescription`, but omitted the separate update-purpose key that Apple expects for a HealthKit-capable target.

## Fix

Added an accurate `NSHealthUpdateUsageDescription` to both iOS Info plists. Its text explicitly states that Routina does not write Apple Health data and identifies the optional Stats connection. Added a configuration test for both HealthKit purpose strings.

## Prevention Rule

When an iOS target enables HealthKit, declare and maintain both HealthKit privacy-purpose strings in every shipped configuration. Keep the strings aligned with the app's actual read/write behavior. If the product deliberately removes HealthKit, remove the implementation, entitlement, and purpose strings together.

## Regression Safeguard

The original purpose-string safeguard was retired with the integration. `AppStoreComplianceConfigurationTests.iOSInitialReleaseOmitsHealthKit` now verifies that both iOS variants omit HealthKit entitlements and purpose strings.

## Current Applicability

[Decision 0697](../decisions/0697-omit-apple-health-from-the-first-release.md) removed HealthKit from the first release. This lesson remains the rule for any future reintroduction.
