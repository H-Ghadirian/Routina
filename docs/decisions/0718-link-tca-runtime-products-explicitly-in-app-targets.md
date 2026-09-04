# 0718 — Keep Hosted Mac Tests on One Runtime Package Graph

## Status

Accepted

## Date

2026-09-03

## Refines

- [0477 — Keep iOS UI Benchmarks Dev-Hosted and Explicitly Linked](0477-keep-ios-ui-benchmarks-dev-hosted-and-explicitly-linked.md)
- [0717 — Ratchet Code Quality With Shared Boundaries](0717-ratchet-code-quality-with-shared-boundaries.md)

## Context

Routina's macOS tests are hosted by `RoutinaMacOSDev` and use `@testable import`
to exercise app-owned features. The test bundle also linked Composable
Architecture, Dependencies, and CasePaths independently. That produced two
owners for the same runtime graph when Xcode loaded the host and test bundle.

At the same time, the Mac application targets compiled code that directly
imports `SwiftUINavigation` without directly linking that package product. A
normal Build could succeed through transitive linkage while a hosted Test action
failed with missing runtime symbols. Xcode's Debug Dylib indirection added a
third action-specific layout to an already ambiguous graph.

## Decision

The macOS Dev and Prod app targets directly link `SwiftUINavigation`, which
their compiled source imports. The hosted macOS test bundle obtains
Composable Architecture, Dependencies, and CasePaths through its host app
instead of linking duplicate copies. It retains direct test-only products such
as Concurrency Extras when test source imports them.

The macOS Dev Debug configuration disables `ENABLE_DEBUG_DYLIB`, keeping
testable app code and its runtime package graph in the conventional host
executable used by the hosted test bundle.

Platform Xcode tests remain part of the quality gate. A package product belongs
to the final target that imports it; hosted tests must not duplicate the host's
runtime products merely to make compile-time imports available.

## Consequences

- Build, build-for-testing, and test actions use one host-owned runtime graph.
- The test bundle avoids duplicate package images and the identity/runtime
  failures they can create.
- Adding a directly imported runtime product requires updating the app target;
  adding a test-only import requires updating the test target.
- The Dev Debug app does not use Xcode's Debug Dylib optimization. Hosted-test
  correctness and a consistent link layout take priority for this target.
