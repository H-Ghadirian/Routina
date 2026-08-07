# 0088 — Keep one-off auto-assume controls out of recurrence-only branches

Date: 2026-08-07

## Symptom

An eligible one-off task with one exact date and a scheduled Time block did not show the Auto-assume done toggle in the macOS form.

## Root Cause

The shared eligibility derivation supported the new one-off case, but the Mac form rendered the toggle only inside its repeating-task schedule-details branch.

## Fix

Render an eligible one-off task's existing Auto-assume done control directly after its date and time availability controls, while retaining the repeating-task placement in schedule details.

## Prevention Rule

When expanding eligibility beyond a previous task category, audit each platform's presentation branches as well as domain eligibility and persistence.

## Regression Safeguard

`TaskFormMacLayoutRegressionTests.eligibleOneOffTasksShowAutoAssumeDoneBesideTheirAvailabilityControls` verifies the one-off availability branch renders the existing control. See [Decision 0492](../decisions/0492-allow-auto-assume-done-for-one-off-scheduled-blocks.md).
