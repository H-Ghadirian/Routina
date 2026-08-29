# 0262 — Pair nested scope state with navigation presentation

Date: 2026-08-28

## Symptom

On iOS, opening a Task Ladder group replaced the current Ladder rows in place.
The native Back button therefore returned directly to Home instead of returning
to the preceding Task Ladder list.

## Root Cause

The group's explicit inner-ladder control sent the reducer action that changed
the Ladder scope, but it did not present a navigation destination. Domain scope
advanced while the native navigation stack remained at the root Ladder level.

## Fix

The iOS Task Ladder now presents each inner group as a destination in Home's
existing navigation hierarchy. Opening the destination advances feature scope,
and dismissing it with native Back restores the preceding scope. A pushed inner
Ladder relies on the native Back control instead of exposing the in-place scope
fallback intended for root-level search navigation.

## Prevention Rule

When nested content is expected to behave as push navigation, update domain
scope and navigation presentation together, and pair native destination
dismissal with restoration of the corresponding parent scope.

## Regression Safeguard

`Tests/Shared/IOSHomeWorkspaceNavigationSourceTests.swift` verifies that the
inner-ladder action presents a navigation destination and that dismissing it
restores the previous scope. The iOS Home workspace scenario records the native
Back behavior from a nested Ladder.
