# 0094 — Explain hidden task Flags in details

Date: 2026-08-07

## Symptom

A task opened from the `Hidden by flag` result section did not identify the
Flag responsible, and Task Details did not show its assigned Flags at all.

## Root Cause

The result section has one generic title because it can contain tasks hidden
by different Flags. The Mac sidebar breadcrumb reused that generic title, and
the separate Flags model had not been added to the Task Detail presentation.

## Fix

Task Details now render assigned Flags on both platforms. The Mac breadcrumb
resolves the selected task's normalized Flag-rule matches and names the hiding
Flag or Flags while preserving the generic shared result-section title.

## Prevention Rule

When a shared result collection has a generic reason label, derive any
task-specific explanation from the selected item's normalized behavior data;
do not assume the collection label is sufficiently precise.

## Regression Safeguard

`RoutineTagTests.flagRules_deduplicateByFlagAndRuleKind` verifies that the
hiding Flag derivation is normalized, deduplicated, and retains the task's
display spelling for the Task Detail UI.
