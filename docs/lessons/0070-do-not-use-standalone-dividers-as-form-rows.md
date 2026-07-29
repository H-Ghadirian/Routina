# 0070 — Do not use standalone dividers as Form rows

Date: 2026-07-29

## Symptom

The iOS task editor showed large empty bands between Task Type, Duration, and
Time Availability, and the five time choices were truncated into ambiguous
labels on a phone-width screen.

## Root Cause

Each `Divider` was a direct child of a SwiftUI `Section`, so `Form` gave it a
full native row height. The same monolithic section also forced five
descriptive choices into one fill-width segmented control.

## Fix

Task Type, Duration, and Availability now use separate Form sections without
standalone divider rows. Date and time availability use native navigation
pickers whose labels remain readable at compact widths.

## Prevention Rule

Do not use a standalone `Divider` to separate logical groups inside a Form
section. Give each logical group its own section, and do not use a segmented
control when the available width cannot preserve every option label.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests` verifies that the task-type editor keeps
separate sections, contains no standalone divider, and presents availability
through navigation pickers rather than a five-way segment.
