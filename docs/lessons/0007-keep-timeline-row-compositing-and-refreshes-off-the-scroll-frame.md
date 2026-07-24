# 0007 — Keep Timeline Row Compositing and Refreshes Off the Scroll Frame

## Symptom

The production Mac Planner Timeline still stuttered during a complete
latest-to-oldest and oldest-to-latest traversal, especially on older MacBook Air
hardware.

## Root Cause

Each newly visible Timeline row created separate Liquid Glass effects for its
icon and kind badge. At the same time, persistence notifications could begin a
full Home reload immediately before a scroll gesture, putting model loading and
display rebuilding on the main actor while native `List` was reusing rows.

## Fix

Repeated Timeline icon and kind-badge decorations now use lightweight tinted
shape fills. Home persistence notifications are coalesced for a short interval
and then recheck the macOS scroll quiet gate before starting a full reload.

## Prevention Rule

Do not place backdrop-sampling effects in every row of an unbounded scrolling
surface unless Release profiling proves they remain frame-safe on older
hardware. Coalesce persistence refreshes before main-actor model work and
recheck active scrolling at the execution boundary.

## Regression Safeguard

The macOS performance regression suite verifies that Timeline rows use the
lightweight scrolling fills and that routine-update refreshes pass through the
coalescing delay.
