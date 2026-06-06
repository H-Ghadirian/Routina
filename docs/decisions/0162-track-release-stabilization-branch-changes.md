# 0162: Track Release Stabilization Branch Changes

## Status

Accepted

## Date

2026-06-06

## Context

The `release/stabilization` branch is allowed to hide unfinished work, fix defects, and improve existing behavior without treating every release-only change as a permanent main-branch decision. Future work may want to reuse some stabilization changes on `main` while reverting or reworking others.

The branch was cut from local `main` at `b1571054` and currently contains release commit `71013a0a`.

## Decision

Keep a release-branch change ledger in this record. When adding release-only changes, update this note with the commit, intent, affected surfaces, and likely main-branch handling before merging, cherry-picking, or reverting.

## Current Release Change Ledger

### `71013a0a`: Hide Adventure for release stabilization

Intent: remove unfinished Adventure user-visible surfaces from the release while preserving the underlying implementation for later iteration.

Affected behavior:

- Removed the macOS Adventure command and its notification route.
- Made Stats the only visible Mac progress mode for release UI.
- Hid the `Stats / Adventure` toolbar segment by exposing only one visible progress mode.
- Rendered the Mac Stats sidebar and detail surfaces as Stats-only.
- Removed release UI construction of `HomeMacAdventureView` and `HomeMacAdventureSidebarView`.
- Normalized stale Adventure sidebar/progress navigation back to Stats.
- Kept Adventure progression, artwork, local unlock settings, and progression tests in the codebase.
- Added [0161: Hide Mac Adventure for Release Stabilization](0161-hide-mac-adventure-for-release-stabilization.md).
- Updated macOS tests so hidden Adventure state is intentional.

Likely main-branch handling:

- Reuse on `main` if Adventure is still not release-ready there: the command removal, visible progress-mode gate, Stats-only rendering, and stale-state normalization can be cherry-picked together.
- Keep or adapt the compatibility normalization if a future feature flag or build setting controls Adventure visibility.
- Revert or skip the command removal, Stats-only rendering, and tests that expect Adventure to be hidden when Adventure becomes ready for users again.
- To re-enable Adventure, restore visible progress modes to include `.adventure`, restore the command/notification/router path, render `HomeMacAdventureView` and `HomeMacAdventureSidebarView` from the progress surfaces, and supersede [0161](0161-hide-mac-adventure-for-release-stabilization.md).

## Consequences

- Release stabilization changes are easier to audit against `main`.
- Main can cherry-pick release improvements without accidentally adopting temporary release hiding decisions.
- Temporary release decisions must stay explicit, because they may need to be reverted independently from bug fixes.
