# 0129 — Verify dictionary inference in iOS builds

Date: 2026-08-10

## Symptom

The iOS development app could not be built or launched after the compact task-tag picker was introduced.

## Root Cause

`TaskFormIOSTagsSection` used the generic `Dictionary` initializer with a `compactMap` result whose key and value types were not inferred by the iOS compiler.

## Fix

Build the cached tag-summary lookup with a typed `reduce(into:)` dictionary instead of the ambiguous generic initializer.

## Prevention Rule

When a generic collection initializer is used in platform-specific SwiftUI code, make the resulting collection type explicit or use a typed accumulator before relying on a shared-package test result.

## Regression Safeguard

`swift test -q` covers the tag-suggestion presentation, and the iOS development target is built and launched on an iOS simulator after changes to `TaskFormIOSOrganizationSection.swift`.
