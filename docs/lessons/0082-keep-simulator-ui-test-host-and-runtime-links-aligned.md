# 0082 — Keep Simulator UI-test host and runtime links aligned

Date: 2026-08-05

## Symptom

The iOS guided-review performance test could not run on the Simulator even
though the generic iOS device build succeeded.

## Root Cause

The UI-test target named the Dev app as its host but depended on the Prod app,
and the Dev scheme did not include UI tests. The Simulator linker also lacked
direct links to `Perception`, `PerceptionCore`, and `SwiftUINavigation`, which
are used by the app through Composable Architecture's feature code.

## Fix

The UI-test target now consistently hosts the Dev app. A dedicated shared
guided-review performance scheme builds only the Dev app and UI-test bundle.
Both iOS app targets explicitly link the needed package products so the
Simulator build-for-testing path resolves their runtime symbols.

## Prevention Rule

Treat a passing generic device build as insufficient for iOS interaction work.
The Simulator UI-test host, target dependency, and direct runtime links must
agree, and a real Simulator benchmark must build and run before relying on a
performance conclusion.

## Regression Safeguard

`RoutinaiOSGuidedReviewPerf` runs
`RoutinaUIPerformanceTests/testSeededGuidedReviewTaskDetailRoundTripPerformance`
against the Dev-hosted app. The benchmark seeded 300 review tasks and 9,000
logs successfully in the regression run.
