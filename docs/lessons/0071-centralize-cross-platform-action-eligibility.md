# 0071 — Centralize cross-platform action eligibility

Date: 2026-07-29

## Symptom

iOS Task Detail showed `Start ongoing` for a one-day Gentle,
checklist-driven routine, while Mac Task Detail correctly omitted that action
for the same task.

## Root Cause

The iOS routine action view contained an extra platform-local eligibility
branch for soft routines. The Mac action surface used the shared status action
set and never added the branch, allowing the two platforms to drift.

## Fix

The iOS-only secondary `Start ongoing` control was removed. Multi-day routines
continue to enter and leave ongoing state through the shared primary
Start/Stop action.

## Prevention Rule

Lifecycle action eligibility must be a cross-platform contract. Do not add a
platform-local Task Detail action without verifying and documenting whether
the same action should appear on the other platform.

## Regression Safeguard

`TaskDetailPlatformActionParityTests` verifies that iOS one-day routine actions
omit the extra ongoing entry point while the shared multi-day primary action
retains Start and Stop behavior.
