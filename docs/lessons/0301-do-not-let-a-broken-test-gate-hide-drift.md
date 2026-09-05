# 0301 — Do not let a broken test gate hide drift

Date: 2026-09-05

## Symptom

The iOS app built, but its hosted unit-test action failed before execution with
missing Perception Core and Swift Navigation symbols. Once the linker was
repaired, the suite exposed many stale assertions that had accumulated behind
the earlier failure.

## Root Cause

The iOS test bundle linked runtime package products already owned by its host,
and the Dev Debug host used Xcode's alternate Debug Dylib layout. The resulting
duplicate runtime graph prevented tests from loading. Treating that early
failure as separate from suite health allowed broad state-snapshot assertions
to drift from shared feature behavior.

## Fix

The Dev host now owns Composable Architecture, Dependencies, and CasePaths for
the hosted suite, while the test target retains only test-specific Concurrency
Extras. The Dev Debug configuration uses the conventional executable layout.
The iOS tests were then executed and updated to assert their owned outcomes,
including current load maintenance, Timeline ordering, Stats refresh, Task
Detail derivation, and localized presentation semantics.

## Prevention Rule

A platform test gate is healthy only when its tests execute. Repair host/linker
failures immediately, then run the entire suite and address all revealed drift.
For aggregate reducer state, assert the behavior under test rather than copying
unrelated derived caches into every expected transition.

## Regression Safeguard

The `RoutinaiOSDev` Simulator test action now builds and loads the host before
running the complete iOS suite. The project quality gate also requires a final
iOS build and launch from the same verified change.

Related decision: [0740 — Keep hosted iOS tests on one runtime package graph](../decisions/0740-keep-hosted-ios-tests-on-one-runtime-package-graph.md).
