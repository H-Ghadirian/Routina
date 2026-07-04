# 0332: Remove Settings From Mac Home Toolbar Strip

## Status

Accepted

## Date

2026-07-04

## Refines

- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)
- [0318: Remove Mac Home Timeline Toolbar Segment](0318-remove-mac-home-timeline-toolbar-segment.md)

## Context

The compact Mac Home toolbar strip is meant to keep high-frequency Home navigation and creation close to search and Focus. Settings is a lower-frequency destination, and keeping it in the toolbar strip adds another icon to the already crowded command row while search and toolbar stability are being simplified.

Settings still needs to remain routeable for restored navigation state, commands, menus, and explicit settings surfaces. The requested change is only to remove the visible Settings segment from the toolbar strip.

## Decision

Mac Home hides Settings from the toolbar-mode strip. The visible toolbar strip keeps Tasks, Goals when enabled, Adventure when enabled, Stats, and Add. The Add separator remains before the Add segment even when Settings is hidden.

The underlying `settings` sidebar mode, settings state, and settings routes remain available for non-toolbar entry points and compatibility.

## Consequences

- The toolbar command row is less crowded.
- Settings remains supported without being a primary toolbar destination.
- Future toolbar strip changes should keep lower-frequency app configuration outside the compact Home toolbar strip unless a later decision explicitly restores it.
