# 0515 Report Signed CloudKit Environment in Diagnostics

Status: Accepted

Date: 2026-08-09

Refines: [0167 Merge iCloud and Backup Settings](0167-merge-icloud-and-backup-settings.md), [0248 Add Explicit Mac Prod Run Entrypoint](0248-add-explicit-mac-prod-run-entrypoint.md)

## Context

The configured data mode and iCloud container identify Routina's intended storage configuration, but neither proves which CloudKit environment the installed executable is entitled to use. Xcode development launches, TestFlight builds, and App Store builds can use the same container identifier while being signed for different CloudKit environments.

When a device appears to be missing iCloud data, diagnostics that present only the configured values can make a signing/environment mismatch look like a sync or data-loss issue.

## Decision

Support & About's hidden Diagnostics section reports a separate `Signed CloudKit Environment` value on iOS and macOS. The value comes from the executable's `com.apple.developer.icloud-container-environment` code-signature entitlement through `SecTaskCopyValueForEntitlement`.

The existing Data Mode and iCloud Container rows remain configuration diagnostics. They must not be presented as proof of the signed CloudKit environment. If the entitlement cannot be read, diagnostics report that condition explicitly rather than inferring an environment.

## Consequences

- Support can distinguish a binary/environment mismatch from a configured-container mismatch before asking a customer to reset or reinstall an app.
- Development, TestFlight, and production Mac builds can be compared using a value reported by each running executable.
- The row is diagnostic-only; it does not change the app's CloudKit configuration, data, or sync behavior.
