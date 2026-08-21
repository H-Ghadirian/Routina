# 0220 — Preserve Planner Card Positions When Prioritizing Visibility

Date: 2026-08-21

## Symptom

The first narrow-card fix kept the title readable but moved the emoji or status icon to a different position, even though the intended change was only to decide which fields remain visible.

## Root Cause

The implementation treated a visibility priority as a layout-order priority. Reordering children changes the card's established visual language instead of simply dropping lower-priority content when width is unavailable.

## Fix

Each height-specific card now offers the original title/time/leading-icon arrangement, the same arrangement without the icon, and a title-only fallback through `ViewThatFits`. The first candidate that fits is selected.

## Prevention Rule

When a product priority describes what to hide, keep the original field positions in every candidate and remove fields from lowest to highest priority. Do not use child order to encode visibility priority.

## Regression Safeguard

`plannerBlockCardsPrioritizeVisibilityWithoutReorderingFieldsWhenWidthIsTight` in `Tests/Shared/DayPlanPlannerStateTests.swift` checks the fallback candidates and confirms the icon/avatar remains before the title in the full layouts. Decision [0622](../decisions/0622-preserve-planner-card-positions-while-prioritizing-visibility.md) and scenario [Planner Block Cards Prioritize Visibility Without Reordering](../scenarios/README.md#planner-block-cards-prioritize-visibility-without-reordering) record the clarified behavior. This lesson supersedes the implementation guidance in [0219](0219-prioritize-planner-block-titles-in-narrow-cards.md), which remains as historical context.
