# 0137 — Use a reliable glyph for the Mac overflow trigger

Date: 2026-08-11

## Symptom

The Mac Task Detail overflow button showed its rounded surface but no visible
vertical-dot mark.

## Root Cause

The `ellipsis.vertical` SF Symbol did not render inside this custom macOS
toolbar-control composition, leaving the control visually empty.

## Fix

The button now uses the explicit `⋮` glyph, which renders consistently inside
the shared toolbar chrome.

## Prevention Rule

When a compact control's icon is its only affordance, verify the exact rendered
symbol in that composition and use a reliable native text glyph when an SF
Symbol does not draw.

## Regression Safeguard

`TaskDetailPlatformActionParityTests.macFullDetailGroupsSecondaryTaskActionsInAnOverflowMenu`
asserts that the overflow trigger contains the explicit visible `⋮` glyph.
