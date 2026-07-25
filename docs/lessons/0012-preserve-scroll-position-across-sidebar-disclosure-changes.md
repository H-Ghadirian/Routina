# 0012 — Preserve scroll position across sidebar disclosure changes

Date: 2026-07-24

## Symptom

Expanding a collapsed top-level section in the Mac task sidebar could move the whole list upward, hiding the toggled header and sections that had been visible around it. `Future` made the issue especially obvious because it commonly reveals many rows, but the defect applied to every top-level disclosure.

## Root Cause

The sidebar relied on SwiftUI and AppKit's implicit scroll anchoring while an animated disclosure changed document height. AppKit could compensate around the focused disclosure control, changing the clip view's origin. Removing animation from one section did not guarantee viewport stability and left every other section exposed to the same behavior.

## Fix

The task-list scroll view is now resolved explicitly. Every user-driven top-level, nested, and bulk disclosure locks its clip-view origin before changing section state, performs the height change in a nonanimated transaction, and observes bounds changes so any framework-generated offset is rejected synchronously before display. The lock remains through the immediate follow-up layout passes and clamps only when collapsed content makes the old offset impossible.

## Prevention Rule

When disclosure changes must not move the user's viewport, temporarily lock the native clip view's bounds origin across the complete layout cycle. Post-layout restoration alone can still expose a transient jumped frame, even without an explicit SwiftUI animation.

## Regression Safeguard

Focused scroll-preservation tests cover retaining a valid origin and clamping it after content shrinkage. The task-list scenario requires continuous viewport stability, without an intermediate jumped frame, for top-level, nested, and bulk disclosure changes.
