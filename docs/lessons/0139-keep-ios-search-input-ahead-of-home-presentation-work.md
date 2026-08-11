# 0139 — Keep iOS search input ahead of Home presentation work

Date: 2026-08-11

## Symptom

Opening iOS Search stuttered while its animation and keyboard appeared. Typing
into Search lagged behind the keyboard, then flushed several queued characters
at once.

## Root Cause

Search selection replaced the whole tab host by conditionally adding its
searchable modifier. Every raw keystroke also invalidated Home's full task-list
presentation token, rebuilding filtering and sections on the main actor during
text entry.

## Fix

The tab host now always owns the searchable modifier. Search keeps raw control
text separate from the applied Home query, debouncing non-empty updates for
120 milliseconds and applying clears immediately.

## Prevention Rule

Never couple a native iOS text-input binding directly to unbounded presentation
work, and do not replace a tab host merely because its Search destination is
selected.

## Regression Safeguard

`Tests/Shared/IOSScrollingPerformanceRegressionTests.swift` checks for the
raw/applied query boundary, cancellation, immediate clear path, stable tab host,
and debounce policy. The behavior is recorded in
`docs/scenarios/README.md` and Decision
[0541](../decisions/0541-keep-ios-search-input-ahead-of-home-presentations.md).
