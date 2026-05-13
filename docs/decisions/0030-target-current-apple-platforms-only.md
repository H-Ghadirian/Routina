# 0030: Target Current Apple Platforms Only

## Status

Accepted

## Date

2026-05-13

## Context

Routina's app targets had moved to the iOS 26 and macOS 26 generation, but some project and package settings still advertised older platform support. Shared UI also kept availability branches and fallback surfaces for earlier operating systems, and view code still used TCA's Perception tracking wrapper for older SwiftUI observation behavior.

Maintaining those older paths made new platform work harder to reason about and conflicted with the product direction to use the current Apple OS and SwiftUI API surface directly.

## Decision

Routina is a current-Apple-platforms-only app. The checked-in baseline follows the newest SDK installed and verified in the project toolchain; at the time of this decision that is Xcode 26.4.1 with iOS, macOS, and watchOS 26.4 SDKs.

App, extension, test, and package targets should use that current baseline, Swift 6 language mode, and native current-platform APIs directly. Do not add older-OS fallbacks, compatibility availability branches, or backported SwiftUI observation wrappers for unsupported operating systems.

When the project toolchain updates to a newer Apple SDK, update all minimum deployment targets and the Swift package tools version together, then verify the normal iOS and macOS builds.

## Consequences

- Routina will not build or run on older iOS, macOS, or watchOS versions.
- Shared Liquid Glass surfaces can call native `glassEffect` directly instead of preserving material fallbacks.
- SwiftUI views should access observable TCA store state directly instead of using `WithPerceptionTracking`.
- Compatibility code may remain only when it protects persisted user data or handles current SDK enum/API requirements rather than supporting old OS releases.
