# 0210 — Reuse Mac task-form tag and flag presentation work

Date: 2026-08-20

## Symptom

Selecting or removing a tag or flag could make the Mac Add Task and Edit Task forms feel unresponsive.

## Root Cause

The shared Mac tag form recomputed related tags, normalized membership checks, available flags, and tag-summary lookups several times during one SwiftUI render. Related-tag derivation sanitized the full rule set on each access, so a small selection change triggered repeated main-thread work before the chips could settle.

## Fix

Build the tag and flag presentation collections once at the start of the form body, use normalized sets for membership checks, and pass the resulting arrays and summary lookup into the chip builders.

## Prevention Rule

When a SwiftUI form renders a collection of selectable chips, derive shared filtered and lookup data once per render and avoid repeated full-list normalization or domain derivation from individual view properties.

## Regression Safeguard

The Mac tag suggestion presentation tests remain in place, and the Mac target compiles the refactored shared Add/Edit form component. A targeted Mac test invocation was blocked at the existing project linker failure for the SwiftUINavigation `confirmationDialog` symbol, after source compilation completed.
