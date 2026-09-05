# 0303 — Keep action fixtures aligned with payload contracts

Date: 2026-09-05

## Symptom

The macOS test target could not compile because two Backlog refresh tests constructed `tasksLoaded` with six payloads after the action had grown to seven.

## Root Cause

The shared Backlog action contract changed, but its macOS `TestStore` expectations were not updated. Package tests did not compile this platform-specific test target, so the stale action fixtures remained hidden.

## Fix

Both expectations now supply correctly typed empty values for all seven payloads, including the future-completion dictionary, defined Flags, and Tag colors.

## Prevention Rule

When an action's associated values change, search every platform test target for direct action construction and compile those targets before considering the contract migration complete.

## Regression Safeguard

`BacklogFeatureTests` now compiles its automatic and manual refresh expectations against the complete `tasksLoaded` payload. The macOS test build is part of verification for this repair.
