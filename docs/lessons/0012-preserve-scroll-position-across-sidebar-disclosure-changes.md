# 0012 — Preserve scroll position across sidebar disclosure changes

Date: 2026-07-24

## Symptom

Expanding a collapsed top-level section in the Mac task sidebar could move the whole list upward, hiding the toggled header and sections that had been visible around it. `Future` made the issue especially obvious because it commonly reveals many rows, but the defect applied to every top-level disclosure.

## Root Cause

The sidebar relied on SwiftUI and AppKit's implicit scroll anchoring while an animated disclosure changed document height. AppKit could compensate around the focused disclosure control, changing the clip view's origin. Removing animation from one section did not guarantee viewport stability and left every other section exposed to the same behavior.

## Fix

The task-list scroll view is now resolved explicitly. Every user-driven top-level, nested, and bulk disclosure captures its clip-view origin before changing section state and restores that origin during and after the animated layout update, clamped only when collapsed content makes the old offset impossible.

## Prevention Rule

When disclosure changes must not move the user's viewport, preserve the native scroll view's content offset explicitly across the layout transaction; do not rely on animation choice or framework anchoring heuristics.

## Regression Safeguard

Focused scroll-preservation tests cover retaining a valid origin and clamping it after content shrinkage. The task-list scenario records the invariant for top-level, nested, and bulk disclosure changes.
