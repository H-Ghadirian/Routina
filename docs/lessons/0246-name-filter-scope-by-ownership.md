# 0246 — Name filter scope by ownership

Date: 2026-08-24

## Symptom

The Mac Planner filter scope labeled `All` contained only cross-surface shared
filters and gave no indication that another scope still had active filters.

## Root Cause

The label described the number of affected surfaces rather than ownership of
the controls, and the scope picker represented selection without filter state.

## Fix

The scope is now `Shared`, every scope has ownership copy, and active scopes
show a compact indicator independently of the selected segment.

## Prevention Rule

Name a filter scope for what it owns, not for an ambiguous quantity, and keep
active filters discoverable when scope navigation hides their controls.

## Regression Safeguard

`Tests/macOS/HomeFeatureTests.swift` protects the scope taxonomy and
`Tests/macOS/PerformanceRegressionTests.swift` protects the ownership copy and
active-indicator wiring.
