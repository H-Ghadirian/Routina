# 0417: Route Feature Data Loading Through Reducers

## Status

Accepted

## Date

2026-07-22

## Context

Some TCA-backed screens query SwiftData or perform mutations directly in SwiftUI views and then send assembled snapshots to their feature reducers. This keeps presentation working, but the data-loading behavior sits outside the feature's action and dependency boundary, which makes it harder to test and reuse consistently.

## Decision

Migrate feature-owned data loading and mutations incrementally into reducer effects backed by injected dependencies. Views may continue to observe platform lifecycle, persistence-save, and preference-change events, but they should translate those events into feature actions rather than executing feature data queries or mutations themselves.

The macOS Stats feature is the first migrated slice: its view reports refresh events, while its reducer fetches SwiftData through the injected model-context provider, applies feature-availability settings, and sends the resulting data through its normal action path.

Large existing workflows should move opportunistically in behavior-preserving slices with focused reducer coverage rather than through a single broad rewrite.

## Consequences

- Feature persistence behavior becomes visible in the TCA action stream and testable with dependency overrides.
- SwiftUI views become more presentation-focused.
- Existing direct-persistence screens remain valid migration candidates; this decision does not require an unsafe all-at-once conversion.
- Platform-specific observation can remain in views when it only triggers an action and does not own the resulting business operation.
