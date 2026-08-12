# 0153 — Link Search-tab selection to search activation

Date: 2026-08-12

## Symptom

Selecting the dedicated iOS Search tab expanded its field, but the keyboard
did not open until the person tapped the field separately.

## Root Cause

Declaring a SwiftUI tab with the Search role identifies where search belongs,
but the default tab-view activation policy leaves field activation to a
separate user interaction. Routina did not opt into activation driven by
Search-tab selection.

## Fix

The stable iOS tab view now uses
`tabViewSearchActivation(.searchTabSelection)`, so selecting or reselecting
Search focuses the native field and opens the keyboard immediately.

## Prevention Rule

For a dedicated Search tab without browse-only landing content, configure tab
selection and search activation as one interaction. Do not assume that a
Search tab role alone defines keyboard-focus behavior.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.searchKeepsInputImmediateWhileDebouncingHomePresentationWork`
guards the activation policy in the stable tab hierarchy.
`RoutinaUIPerformanceTests.testSearchTabActivationPerformance` and
`testLargeSeededRapidNoMatchSearchPerformance` verify that selecting Search
opens the keyboard before any explicit field tap. Decision
[0558](../decisions/0558-activate-ios-search-on-tab-selection.md) records the
durable behavior.
