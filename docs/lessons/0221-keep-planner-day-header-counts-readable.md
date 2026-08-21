# 0221 — Keep Planner Day Header Counts Readable

Date: 2026-08-21

## Symptom

The planned-task count at the top of a Planner day column displayed an ellipsis even when the header visibly had room for the count.

## Root Cause

The button's `minWidth` constrained the outer control but did not protect the inner `Label` from receiving a compressed width proposal. Its single-line text could therefore ellipsize inside an otherwise wide pill.

## Fix

The day-header count labels now use intrinsic horizontal sizing before the pill padding and minimum frame are applied, preserving the visible numeric count and the existing full accessibility text.

## Prevention Rule

For short, semantically important labels inside flexible header controls, protect the label's intrinsic horizontal width in addition to sizing the outer button.

## Regression Safeguard

`plannerDayHeaderTaskCountKeepsItsNumericLabelIntrinsicWidth` in `Tests/Shared/DayPlanPlannerStateTests.swift` verifies the day-task label keeps its one-line, intrinsic-width layout. Decision [0623](../decisions/0623-keep-planner-day-header-task-counts-unellipsized.md) and the [Planner day-header count scenario](../scenarios/README.md#planner-day-headers-open-planned-task-lists) record the behavior.

