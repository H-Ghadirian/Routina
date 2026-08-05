# 0477: Keep iOS UI Benchmarks Dev-Hosted and Explicitly Linked

## Status

Accepted

## Date

2026-08-05

## Context

The UI-test target declared the Dev app as its test host but depended on the
Prod app, while the normal Dev scheme did not include UI tests. In addition,
the iOS Simulator linker did not carry the transitive Perception and SwiftUI
Navigation runtime products needed by Composable Architecture. A generic device
build therefore passed while the actual Simulator performance path could not
build or run.

## Decision

The UI-test target uses `RoutinaiOSDev` consistently as its target dependency,
test target, and host. A dedicated `RoutinaiOSGuidedReviewPerf` shared scheme
builds only that Dev app and its UI-test bundle, keeping the performance route
independent of unrelated unit-test compilation failures.

Both iOS application targets directly link the `Perception`, `PerceptionCore`,
and `SwiftUINavigation` Swift Package products required by their compiled
feature code. These direct links make Simulator build-for-testing deterministic
under the current Xcode linker rather than relying on transitive package
linkage.

## Consequences

- A seeded iOS UI benchmark can exercise production-like card/detail navigation
  on a Simulator.
- Device builds and Simulator builds both validate the package runtime graph.
- The regular Dev scheme remains focused on its existing unit-test selection.
