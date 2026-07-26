# 0044 — Keep progressive controls after their trigger

Date: 2026-07-26

## Symptom

Changing Repeat from `No schedule` to `Item runout` moved the Repeat selector
downward because Duration, Time availability, Due style, and a task-list
preview appeared above it. A checklist interval control also appeared below,
making one choice look like several unrelated form changes.

## Root Cause

The Mac Behavior card rendered cadence-dependent modules before the recurrence
control that enabled them. Conditional visibility was correct, but the visual
dependency order was reversed.

## Fix

Completion and Repeat now remain stable. Cadence-dependent modules appear after
Repeat inside one collapsed `Schedule details` disclosure, while each
item-runout interval is edited beside its checklist item title.

## Prevention Rule

Progressively disclosed controls must appear after the control that enables
them. If several secondary defaults become relevant together, reveal one
compact summary/disclosure rather than inserting several independent modules.

## Regression Safeguard

`Tests/macOS/FormSectionTests.swift` protects the Completion -> Repeat ->
Schedule details order and the collapsed schedule summary. Shared presentation
tests protect the `Every N days` item-runout wording, and the Mac task-form
scenario records the stable interaction.
