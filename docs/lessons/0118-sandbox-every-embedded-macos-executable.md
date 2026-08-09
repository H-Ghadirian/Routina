# 0118 — Sandbox every embedded macOS executable

Date: 2026-08-09

## Symptom

App Store Connect rejected the macOS archive because the embedded `RoutinaAIMCPServer` executable did not include `com.apple.security.app-sandbox`.

## Root Cause

The app build script compiled the Swift Package helper and re-signed it with hardened runtime only. The enclosing app's entitlements do not automatically become code-signature entitlements on an embedded executable.

## Fix

Added a dedicated helper entitlements file with the required App Sandbox and inheritance keys, then passed it to the helper's `codesign` invocation.

## Prevention Rule

Every Mach-O executable embedded in a sandboxed Mac App Store app must be signed and inspected as its own executable. A child helper that inherits the parent sandbox must contain exactly `com.apple.security.app-sandbox` and `com.apple.security.inherit`.

## Regression Safeguard

`AppStoreComplianceConfigurationTests.embeddedMacMCPHelperInheritsTheAppSandbox` validates the exact helper entitlements and the embedding script's entitlements/signing arguments. The matching regression scenario is recorded in `docs/scenarios/README.md`.
