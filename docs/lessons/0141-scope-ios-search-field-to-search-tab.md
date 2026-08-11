# 0141 — Scope the iOS search field to its Search tab

Date: 2026-08-11

## Symptom

The task Search field appeared above Home, Timeline, and More even though iOS
already provides a dedicated bottom Search tab.

## Root Cause

The searchable modifier was moved from a conditional Search branch to the
shared tab host while stabilizing the host for the Search transition. A
modifier on that host affects every retained tab destination.

## Fix

The searchable modifier and its raw-input update handler now belong to the
dedicated Search tab content. The tab host remains stable and the existing
debounced applied-query boundary is unchanged.

## Prevention Rule

Global navigation-host modifiers must be scoped to the destination that owns
their visible control unless the control is intentionally shared by every tab.

## Regression Safeguard

`Tests/Shared/IOSScrollingPerformanceRegressionTests.swift` verifies that the
task Search field is attached to Search content rather than the shared tab host.
Decision [0544](../decisions/0544-scope-ios-search-field-to-dedicated-search-tab.md)
and the iOS Search scenario define the expected behavior.
