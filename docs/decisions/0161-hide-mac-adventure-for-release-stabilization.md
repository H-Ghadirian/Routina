# 0161: Hide Mac Adventure for Release Stabilization

## Status

Accepted

## Date

2026-06-06

## Refines

- [0150: Add Mac Adventure Progression MVP](0150-add-mac-adventure-progression-mvp.md)
- [0151: Combine Mac Stats and Adventure in One Tab](0151-combine-mac-stats-and-adventure-tab.md)
- [0152: Support Choice-Based Mac Adventure Unlocks](0152-support-choice-based-mac-adventure-unlocks.md)
- [0153: Make Mac Adventure Worlds and Creatures Explicit Unlocks](0153-make-mac-adventure-worlds-and-creatures-explicit-unlocks.md)

## Context

Adventure is implemented as a Mac-only game layer with map artwork, coins, XP, worlds, stage creatures, and item unlocks, but it is not ready for the release stabilization branch. The release should avoid exposing unfinished game surfaces while preserving the implementation and local state for continued iteration after release.

## Decision

Routina Mac keeps the Adventure progression, unlock, local setting, artwork, and tests in the codebase, but release UI hides every user-visible Adventure entry point.

Stats is the only visible progress mode. The Mac command menu no longer exposes Adventure, the combined Stats toolbar no longer shows a `Stats / Adventure` segment, and the Stats sidebar/detail surfaces render Stats only. Compatibility routes that still reference the old Adventure sidebar mode or progress mode normalize back to Stats.

## Consequences

- Users do not see the Adventure map, coins, worlds, stage creatures, item unlocks, or Adventure command in the release UI.
- Existing local Adventure unlock setting values and bundled artwork remain intact for future iteration.
- Re-enabling Adventure should be an explicit product decision that restores visible progress modes and command/menu access when the surface is release-ready.
