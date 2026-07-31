# 0073 — Declare export compliance in production plists

Date: 2026-08-01

## Symptom

Every newly uploaded build appeared in App Store Connect with `Missing Compliance` and required the encryption questionnaire to be answered manually.

## Root Cause

The macOS and iOS production Info.plists omitted `ITSAppUsesNonExemptEncryption`. App Store Connect therefore could not reuse Routina's stable exempt-encryption answer, even though the app only used exempt Apple platform encryption and SHA-256 for OAuth PKCE.

## Fix

Both production Info.plists now set `ITSAppUsesNonExemptEncryption` to `false`. The next upload build number is 6 because build 5 is already present in App Store Connect.

## Prevention Rule

Every shipping target must explicitly declare its export-compliance status. Reaudit that declaration whenever adding custom cryptography, encrypted communications or VPN features, or a dependency with its own cryptographic implementation.

## Regression Safeguard

`AppStoreComplianceConfigurationTests` parses both production Info.plists and requires the declaration to remain present and false.
