# 0697: Omit Apple Health From the First Release

## Status

Accepted

## Date

2026-08-30

## Supersedes

- [0096: Show HealthKit Movement Stats in iOS Stats](superseded/0096-show-healthkit-movement-stats.md)
- [0550: Make Apple Health Stats Prompt Dismissible](superseded/0550-make-apple-health-stats-prompt-dismissible.md)

## Context

The optional Apple Health integration added a Stats connection prompt, movement
summary cards, HealthKit query code, privacy-purpose strings, and a HealthKit
entitlement to both iOS variants. The first release should keep Stats focused on
Routina-owned activity and should not request a sensitive platform capability
that is not part of the initial product scope.

Merely hiding the prompt would leave the framework implementation and signed
capability in the app. The release boundary therefore needs to remove the
integration itself rather than add another runtime flag or replacement
dependency.

## Decision

- The first iOS and iPadOS release does not offer Apple Health connection or
  movement metrics.
- Routina removes the Health access prompt, movement cards, Health summary
  model, Health client, reducer state and effects, and dashboard-item cases.
- Both iOS variants omit HealthKit imports, HealthKit entitlements, and Health
  privacy-purpose strings.
- No third-party or alternative health library replaces HealthKit.
- Reintroducing health data later requires a new product decision, explicit
  privacy review, capability configuration, and release-scoped tests.

## Consequences

- Stats never prompts for Apple Health permission and exposes no Health-related
  item in Edit or Add to Stats.
- The app binary does not contain Routina HealthKit query code or declare the
  HealthKit capability.
- Saved dashboard customization from development builds may retain obsolete
  Health item identifiers; the existing typed dashboard-item decoding ignores
  them without affecting the remaining order.
- A configuration regression test protects the entitlement and privacy-key
  boundary for both development and production iOS variants.
