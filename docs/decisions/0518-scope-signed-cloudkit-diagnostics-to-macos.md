# 0518 Scope Signed CloudKit Diagnostics to macOS

Status: Accepted

Date: 2026-08-09

Refines: [0515 Report Signed CloudKit Environment in Diagnostics](0515-report-signed-cloudkit-environment-in-diagnostics.md)

## Context

Routina originally used `SecTaskCopyValueForEntitlement` to report the CloudKit environment from the running executable's code signature. That public Security API is available on macOS but not iOS. TestFlight and App Store iOS installations also do not expose an embedded provisioning profile that can provide an equivalent signed-entitlement fallback.

## Decision

On macOS, Diagnostics reads and reports `com.apple.developer.icloud-container-environment` from the running executable's signed entitlements. On iOS, the same Diagnostics row explicitly reports `Unavailable on iOS` rather than inferring Development or Production from the configured container or data mode.

## Consequences

- A macOS diagnostic report can verify the signed CloudKit environment.
- An iOS diagnostic report remains honest about the unavailable public verification API and still includes its configured CloudKit values and sync events.
- iOS builds do not attempt to use private APIs or parse a provisioning profile that TestFlight and App Store builds lack.
