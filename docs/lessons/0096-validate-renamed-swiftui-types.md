# 0096 — Validate renamed SwiftUI types before committing

Date: 2026-08-07

## Symptom

The macOS app could not compile because the Flags Settings view declaration had
no type name, and its rule-status interpolation used invalid escaping.

## Root Cause

A view extraction left `struct : View` in the source, while escaped quotes
inside a Swift interpolation prevented the parser from matching the expression.

## Fix

Restored the `SettingsMacFlagsDetailView` declaration and derived the rule
status in a local Boolean before interpolating it.

## Prevention Rule

After extracting or renaming a SwiftUI view, syntax-check the whole containing
file before committing. Keep complex interpolation expressions out of string
literals when a local value is clearer.

## Regression Safeguard

`swiftc -parse RoutinaMacApp/Screens/Settings/SettingsMacTagsDetailView.swift`
passes for the repaired file; the macOS app build also compiles this source.
