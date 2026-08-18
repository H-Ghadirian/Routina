# 0195 — Show icon-only before date-label truncation

Date: 2026-08-18

## Symptom

The macOS Planner `Go to date` button remained visible but displayed an ellipsized date/range label when the header became too narrow.

## Root Cause

The header's compact fallback constrained the date control's width while retaining its text label. The control had enough semantic identity to work as an icon-only action, but the layout did not switch to that presentation when the measured regular date-control row overflowed.

## Fix

The header now measures the regular date controls and renders the `Go to date` button as a calendar icon-only control when those controls no longer fit. The accessible label, value, help, and full button hit area remain unchanged.

## Prevention Rule

When a compact macOS control has a clear icon-only representation, switch presentation before constraining user-facing text into an ellipsis. Keep the selected value available through accessibility metadata rather than relying on truncated visual text.

## Regression Safeguard

`DayPlanPlannerStateTests.datePickerButtonSwitchesToIconOnlyBeforeRegularDateTextOverflows` covers the width decision, while `Tests/macOS/PerformanceRegressionTests.swift` guards the source-level layout contract. The behavior is also captured in `docs/scenarios/go-to-date-button-becomes-icon-only-when-header-is-tight.md`.
