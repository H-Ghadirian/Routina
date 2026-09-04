# 0288 — Give hosted runtime products one owner

Date: 2026-09-03

## Symptom

The macOS app built normally, but its hosted Xcode Test action failed to link or
load the Dev host consistently while package tests remained green.

## Root Cause

The app directly imported SwiftUI Navigation without owning that product, while
the hosted test bundle independently linked Composable Architecture,
Dependencies, and CasePaths that were already owned by the host. Xcode's Debug
Dylib layout made the difference between ordinary and hosted actions larger.

## Fix

Both macOS application targets now link `SwiftUINavigation`. The hosted test
bundle no longer links duplicate host-owned TCA runtime products, and the Dev
Debug host disables `ENABLE_DEBUG_DYLIB` so tests load one conventional app
executable. Test-only Concurrency Extras remains a test dependency.

## Prevention Rule

Declare directly imported runtime products on the final app target. In a hosted
test setup, do not also link the host's runtime products into the test bundle;
add only products that test source uniquely imports.

## Regression Safeguard

The macOS Xcode Test action is part of the repository quality workflow and local
completion gate. It builds and loads the Dev host before executing tests, so
missing or duplicated runtime ownership fails verification.

Related decision: [0718 — Keep hosted Mac tests on one runtime package graph](../decisions/0718-link-tca-runtime-products-explicitly-in-app-targets.md).
