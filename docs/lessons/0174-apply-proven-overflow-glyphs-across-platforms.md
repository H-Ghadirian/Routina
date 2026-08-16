# 0174 — Apply proven overflow glyphs across platforms

Date: 2026-08-16

## Symptom

The iOS Task Detail top-trailing overflow button showed its toolbar surface but
no visible vertical-dot mark.

## Root Cause

The iOS toolbar reused the `ellipsis.vertical` SF Symbol name even though that
symbol had already proved unreliable in the matching Mac Task Detail control.
The menu and its hit target were present, but its only visible affordance did
not render.

## Fix

The iOS overflow trigger now uses the same explicit `⋮` text glyph as the
working Mac control.

## Prevention Rule

When an icon-only affordance needs a fallback because a named system symbol
does not render, apply the verified fallback to every matching platform
surface rather than leaving another target on the failing symbol.

## Regression Safeguard

`TaskDetailPlatformActionParityTests.iosTaskDetailsGroupMaintenanceActionsInNavigationOverflow`
requires the explicit visible `⋮` glyph and rejects `ellipsis.vertical` in
the iOS Task Detail toolbar source. The existing iOS maintenance-action
scenario continues to require a visible top-trailing vertical-ellipsis menu.

Related lesson: [0137 — Use a reliable glyph for the Mac overflow trigger](0137-use-reliable-glyph-for-mac-overflow-trigger.md).
