# 0068 — Prioritize segment labels at compact widths

Date: 2026-07-29

## Symptom

The `Routines` option in the iOS Home Filters Task Type control was always
truncated, even though `All` and `Todos` remained readable.

## Root Cause

Three equal-width segments each combined a symbol, label spacing, text, and
default horizontal padding. At the filter sheet's compact content width, the
longest label was compressed to make room for decoration.

## Fix

The Task Type control now uses consistent text-only segments, compact horizontal
padding, and a minimum segment width that fits the complete `Routines` label.

## Prevention Rule

In compact segmented controls, reserve space for the longest required label
before adding decorative symbols. Remove nonessential symbols when they make
peer options inconsistent or force meaningful text to truncate.

## Regression Safeguard

`HomeIOSTaskTypeSegmentLayoutTests` isolates the Task Type section and verifies
that it uses full fixed-size text labels, compact padding, and no competing
`Label` symbols. The matching scenario is recorded in
`docs/scenarios/README.md`.

## Follow-up

[Decision 0696](../decisions/0696-use-grouped-rows-for-ios-home-filter-choices.md)
later replaced the Home Task Type segments with native grouped rows. The broader
prevention rule still applies wherever compact segmented controls remain.
