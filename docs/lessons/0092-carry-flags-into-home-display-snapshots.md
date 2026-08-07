# 0092 — Carry flags into Home display snapshots

Date: 2026-08-07

## Symptom

Tasks carrying a Flag with `Hide tasks from normal task lists` could remain in
ordinary Home task-list placement, and their Flags were unavailable to Home's
new Flag filter.

## Root Cause

The shared display factory correctly derived task Flags, but the iOS and macOS
Home display constructors did not copy `core.flags`. Their `flags` property
therefore used the empty default before task-list predicates and filter catalogs
read it.

## Fix

Both platform display mappings now pass `core.flags`, and Home refreshes the
cached Flag filter catalog from those displays.

## Prevention Rule

When a Home predicate or filter catalog depends on a display property, copy the
property from the shared core into every platform-specific Home display mapping.

## Regression Safeguard

The iOS and macOS `HomeFeatureTests.refreshDisplaysCarriesFlagsIntoTaskListDisplaysAndFilterOptions`
tests cover the platform mappings. Shared task-list filtering tests cover
normalized `All` and `Any` Flag matching and the presentation-only hidden
result section.
