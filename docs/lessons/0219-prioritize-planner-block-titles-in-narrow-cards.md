# 0219 — Prioritize Planner Block Titles in Narrow Cards

Date: 2026-08-21

## Symptom

Narrow macOS Planner Schedule cards could show only a small fragment of a task title while reserving space for the emoji or status icon at the leading edge.

## Root Cause

The card's compact layouts rendered the icon before the title and did not give the title, time, and icon explicit competing layout priorities. As columns narrowed, the title was left with whatever space remained after the icon and time.

## Fix

The compact card layouts now order title, time, and icon in priority order and assign descending SwiftUI layout priorities. Larger cards keep title and time ahead of the trailing avatar. The stored Planner block and its timing remain untouched.

## Prevention Rule

Any Planner card content that can become narrower than its intrinsic fields must declare an explicit user-value priority rather than relying on child order or default layout negotiation.

## Regression Safeguard

`plannerBlockCardsKeepTitleBeforeTimeBeforeEmojiWhenWidthIsTight` in `Tests/Shared/DayPlanPlannerStateTests.swift` records the original implementation's field-order assertion. Decision [0621](../decisions/superseded/0621-prioritize-planner-block-title-in-constrained-widths.md) documents that historical interpretation; the corrected rule is in [0622](../decisions/0622-preserve-planner-card-positions-while-prioritizing-visibility.md), with scenario [Planner Block Cards Prioritize Visibility Without Reordering](../scenarios/README.md#planner-block-cards-prioritize-visibility-without-reordering).
