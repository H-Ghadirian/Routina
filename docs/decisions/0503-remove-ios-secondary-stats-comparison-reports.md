# 0503: Remove iOS Secondary Stats Comparison Reports

## Status

Accepted

## Date

2026-08-08

## Refines

- [0109](0109-show-focus-work-comparison.md)
- [0112](0112-show-estimated-actual-time-stats.md)

## Context

Focus versus completed work and estimated versus actual time are useful
comparisons, but they make the iOS Stats dashboard denser than its current
summary-first design needs. macOS already treats both as secondary reports.

## Decision

iOS treats Focus vs completed work and Estimated vs Actual time as unavailable
Stats dashboard reports. They do not render in the dashboard and cannot be
restored through its Edit or Add controls.

The chart implementations and shared metric derivation remain available for
macOS. macOS retains its existing hidden-by-default, addable policy.

## Consequences

- iOS Stats has two fewer secondary dashboard sections and Add choices.
- Existing iOS dashboard order and hidden preferences can retain the old IDs;
  unavailable reports are simply omitted.
- A future iOS restoration can re-enable the two report availability cases
  without migrating stored preferences or removing the macOS reports.
