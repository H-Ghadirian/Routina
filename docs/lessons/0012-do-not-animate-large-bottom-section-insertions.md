# 0012 — Do not animate large bottom-section insertions

Date: 2026-07-24

## Symptom

Expanding the collapsed `Future` section in the Mac task sidebar moved the whole list upward, hiding the section header and the sections that had been visible above it.

## Root Cause

`Future` can insert many rows beneath the bottom-most section header. Performing that large height change in the header button's animated transaction caused the macOS scroll view to compensate around the focused disclosure control, changing the viewport instead of leaving the newly revealed content below it.

## Fix

Opening `Future` now performs its layout insertion without animation, preserving the existing scroll offset. Closing `Future` and toggling other sections keep their existing animation.

## Prevention Rule

Do not animate a potentially unbounded insertion beneath a disclosure header near the end of a macOS scroll view when the interaction contract requires the viewport to remain fixed.

## Regression Safeguard

A focused toggle-policy test requires opening `Future` to be nonanimated while closing it and toggling other sections remain animated. The task-list scenario records the viewport-preservation expectation.
