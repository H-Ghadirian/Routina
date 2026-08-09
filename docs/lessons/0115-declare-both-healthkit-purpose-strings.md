# 0115 — Declare both HealthKit purpose strings

Date: 2026-08-09

## Symptom

App Store Connect rejected an iOS upload with server error 90683 because the production `Info.plist` did not contain `NSHealthUpdateUsageDescription`.

## Root Cause

Routina correctly declared its read-only HealthKit purpose with `NSHealthShareUsageDescription`, but omitted the separate update-purpose key that Apple expects for a HealthKit-capable target. The HealthKit feature itself is intentional and reads optional movement data only.

## Fix

Added an accurate `NSHealthUpdateUsageDescription` to both iOS Info plists. Its text explicitly states that Routina does not write Apple Health data and identifies the optional Stats connection. Added a configuration test for both HealthKit purpose strings.

## Prevention Rule

When an iOS target enables HealthKit, declare and maintain both HealthKit privacy-purpose strings in every shipped configuration. Keep the strings aligned with the app's actual read/write behavior; do not remove a real HealthKit capability merely to suppress a configuration requirement.

## Regression Safeguard

`AppStoreComplianceConfigurationTests.iOSHealthKitPurposeStringsDescribeOptionalReadOnlyStats` parses the development and production Info plists and verifies their exact, user-facing HealthKit descriptions.
