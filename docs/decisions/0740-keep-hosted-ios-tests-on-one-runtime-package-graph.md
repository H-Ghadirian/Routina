# 0740 — Keep Hosted iOS Tests on One Runtime Package Graph

## Status

Accepted

## Date

2026-09-05

## Refines

- [0477 — Keep iOS UI Benchmarks Dev-Hosted and Explicitly Linked](0477-keep-ios-ui-benchmarks-dev-hosted-and-explicitly-linked.md)
- [0717 — Ratchet Code Quality With Shared Boundaries](0717-ratchet-code-quality-with-shared-boundaries.md)
- [0718 — Keep Hosted Mac Tests on One Runtime Package Graph](0718-link-tca-runtime-products-explicitly-in-app-targets.md)

## Context

`RoutinaiOSTests` is hosted by `RoutinaiOSDev` and uses `@testable import` to
exercise app-owned features. The test bundle also linked Composable
Architecture, Dependencies, and CasePaths independently even though the host
already owned those runtime products. Loading both graphs caused the Simulator
test action to fail with missing Perception Core and Swift Navigation symbols,
while ordinary app builds continued to succeed.

Because the hosted suite could not start, its assertions also drifted behind
shared feature behavior without producing a useful test report.

## Decision

The iOS Dev host owns the runtime package graph used by hosted unit tests.
`RoutinaiOSTests` does not independently link Composable Architecture,
Dependencies, or CasePaths; it retains direct test-only products such as
Concurrency Extras. The iOS Dev Debug configuration disables
`ENABLE_DEBUG_DYLIB`, giving the hosted suite one conventional executable and
runtime graph.

Hosted iOS tests use focused assertions for the behavior each test owns instead
of restating complete derived presentation caches. Shared-feature expectations
must track the same current semantics exercised by macOS and package tests.

## Consequences

- Simulator build, test, and launch actions use one host-owned runtime graph.
- Runtime package ownership follows the final target that imports the product.
- Test-only dependencies remain explicit on the test bundle.
- A hosted-suite linker failure is a broken quality gate, not an acceptable
  substitute for executing the tests.
- Focused assertions preserve behavioral coverage while avoiding unrelated
  failures whenever a derived state snapshot gains a field.
