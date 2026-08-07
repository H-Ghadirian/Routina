# 0097 — Verify shared component references in platform forms

Date: 2026-08-07

## Symptom

The macOS app build failed when rendering the Assumed Done section of the task
form because its card component could not be found.

## Root Cause

The new section referenced `TaskFormMacDetailCard`, an obsolete name. The form
uses `TaskFormMacSectionCard` as its shared card component.

## Fix

Replaced the obsolete reference with `TaskFormMacSectionCard`.

## Prevention Rule

When adding a section to a platform-specific SwiftUI form, reuse a component
name already defined in that form file rather than assuming a parallel name
exists.

## Regression Safeguard

The macOS target build compiles the complete form and catches unresolved shared
component references.
