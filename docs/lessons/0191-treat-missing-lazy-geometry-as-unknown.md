# 0191 — Treat missing lazy geometry as unknown

Date: 2026-08-17

## Symptom

The iOS Task Detail navigation title appeared after the full header title
scrolled away, but disappeared again when the person scrolled far enough for
Calendar to reach the top of the screen.

## Root Cause

The full title lived in a `LazyVStack`. Once that header moved far enough
off-screen, SwiftUI stopped realizing it and its bounds-anchor preference became
`nil`. The visibility calculation treated missing geometry as if the full title
were visible, reversing the already-correct collapsed-title state.

## Fix

Missing title geometry now preserves the most recent measured visibility. A
concrete title position still shows or hides the navigation title at the normal
viewport threshold, and changing tasks still resets the state before measuring
the new header.

## Prevention Rule

When UI state depends on geometry from a lazy child, treat a missing preference
as unknown rather than as a visible, hidden, or zero-position measurement.
Preserve the last concrete result until the child publishes geometry again.

## Regression Safeguard

`TaskDetailOverviewHeightsPreferenceKeyTests` verifies that missing geometry
preserves a visible collapsed title, while concrete positions continue to own
the transition. The iOS Task Detail scenario also requires the navigation title
to remain visible as Calendar and later sections reach the top of the viewport.

Related lesson: [0186 — Show collapsed titles only after source titles leave](0186-show-collapsed-titles-only-after-source-titles-leave.md).
Related decision: [0597 — Show iOS Task Detail Title After Header Scrolls Away](../decisions/0597-show-ios-task-detail-title-after-header-scrolls-away.md).
