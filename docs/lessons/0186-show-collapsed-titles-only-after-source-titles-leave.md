# 0186 — Show collapsed titles only after source titles leave

Date: 2026-08-16

## Symptom

iOS Task Details repeated a full task title in the first card and a truncated
emoji-and-name version in the navigation bar at the same time. The duplicate
looked crowded and the fixed navigation width made the less useful copy visually
prominent.

## Root Cause

The navigation identity was treated as permanent toolbar content. It did not
observe whether the full source title was still visible, so an attempt to provide
more identity context created duplication instead of a true collapsed-title
transition.

## Fix

The full header title publishes a lightweight bounds anchor. Task Details keeps
the navigation principal empty until that title has fully left the viewport, then
shows a text-only collapsed title using the available principal width. Scrolling
back hides it again.

## Prevention Rule

When a compact navigation title repeats a prominent title in scrollable content,
make it conditional on the source title's visibility. Do not spend toolbar width
on decorative identity that is already fully visible below.

## Regression Safeguard

`TaskDetailOverviewHeightsPreferenceKeyTests` protects the visibility threshold.
`TaskDetailPlatformActionParityTests` protects the title anchor, conditional
toolbar wiring, removal of the emoji, and removal of the fixed width cap.

Related decision: [0597 — Show iOS Task Detail Title After Header Scrolls Away](../decisions/0597-show-ios-task-detail-title-after-header-scrolls-away.md).
