# 0209 — Treat attached interactive previews as one focus boundary

Date: 2026-08-20

## Symptom

Mac toolbar Quick Add collapsed its parser preview as soon as the person clicked the reminder menu, so the menu appeared without the context needed to finish configuring the task.

## Root Cause

The outside-click monitor recognized only the visible search pill as inside Quick Add, while the AppKit search editor independently collapsed the search whenever it resigned first responder. The attached SwiftUI preview was visually part of Quick Add but absent from both interaction-boundary checks.

## Fix

The parser preview now publishes an AppKit interaction region. Both the outside-click monitor and the search editor's end-editing path recognize mouse events inside that region, and menu events from their temporary AppKit window do not dismiss the owning Home-window search.

## Prevention Rule

When a focused control owns an attached interactive surface, define one explicit interaction boundary and apply it to every focus-loss and outside-click path. Do not infer that a visual child is inside merely because SwiftUI renders it nearby.

## Regression Safeguard

The Mac source regression test requires the preview interaction marker, outside-click boundary check, editor end-editing check, and menu-window guard. The Quick Add scenario records that reminder and custom-date interactions keep the preview open while an actual outside click or Escape dismisses it.
