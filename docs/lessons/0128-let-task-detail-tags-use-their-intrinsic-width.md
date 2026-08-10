# 0128 — Let task-detail tags use their intrinsic width

Date: 2026-08-10

## Symptom

iOS Task Details truncated tag labels even when the header card had enough unused horizontal space to show them in full.

## Root Cause

The shared Task Detail tag section used an 88-point adaptive grid. On wider header cards, SwiftUI created many narrow columns, so each tag chip was measured in a small cell instead of at its intrinsic width.

## Fix

The tag section now uses the existing intrinsic-width flow layout. Chips retain their complete label and wrap only when their combined widths exceed the header card.

## Prevention Rule

Use an intrinsic-width wrapping layout for variable-length metadata chips. Do not use a narrow adaptive grid when labels should consume the available row space before wrapping.

## Regression Safeguard

`Tests/Shared/TaskDetailTagPresentationTests.swift` verifies that the shared Task Detail tag section uses `HomeFilterFlowLayout` rather than the narrow adaptive grid. The Task Detail Tags scenario records the expected behavior.
