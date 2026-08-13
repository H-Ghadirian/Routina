# 0156 — Keep iOS performance flows aligned with compact navigation

Date: 2026-08-13

## Symptom

The iPhone performance audit could not complete its filter, task-detail,
guided-review, and tab-switching paths after the compact More hierarchy and
the dedicated tag-picker flow were introduced. Its long traversal helpers
could also spend minutes waiting for XCUITest animation-idle checks rather
than measuring product work.

## Root Cause

The UI test addressed former top-level Stats and Settings tabs even though the
compact iPhone layout exposes those screens through More. It also tried to
toggle task-row text instead of the nested tag picker, and assumed a small set
of task-detail back labels. It also used hundreds of automatic swipe gestures
for a single flow.

## Fix

The performance suite now follows the compact More and Review tasks routes,
uses the tag picker's explicit accessibility actions, recognizes each Home
list title as a valid detail back control, and bounds traversal gestures while
preserving bidirectional list interaction coverage.

## Prevention Rule

When reorganizing an iOS flow, update the performance journey through the
actual compact navigation hierarchy and target explicit accessibility labels.
Keep UI-test gesture counts bounded so XCUITest synchronization overhead does
not masquerade as product performance.

## Regression Safeguard

`RoutinaUIPerformanceTests` now exercises compact tab switching, nested tag
selection, guided-review detail round trips, creation/removal, and bounded
Home/Stats/Timeline scrolling on seeded simulator data.
