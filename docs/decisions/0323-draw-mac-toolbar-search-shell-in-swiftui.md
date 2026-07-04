# 0323: Draw Mac Toolbar Search Shell in SwiftUI

## Status

Accepted

## Date

2026-07-01

## Refines

- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)
- [0321: Use Focus-Expanded Mac Home Toolbar Search](0321-use-focus-expanded-mac-home-toolbar-search.md)

## Refined By

- [0329: Hide Mac Toolbar Actions During Search Focus](0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

The focus-expanded principal toolbar search should animate like Outlook: the search surface and its icon, text, placeholder, and clear affordance move as one coordinated object. Using a visible `NSSearchField` for that control made the rounded field shell resize first and the native search-cell contents relayout afterward, producing a staggered expand/collapse animation. Attempts to override `NSSearchFieldCell` fixed one timing problem but broke AppKit editing and click behavior.

The search still needs AppKit-owned first responder behavior so the Quick Add shortcut, delayed focus restoration after search filtering, Return-to-create, and intentional focus moves into editors keep working.

## Decision

Mac Home draws the visible toolbar search shell in SwiftUI: rounded background, magnifying-glass icon, placeholder, and in-field clear button. A transparent AppKit `NSTextField` inside that shell owns actual text editing, first responder state, Return/Esc handling, and search update focus restoration.

The search control remains in the centered principal toolbar slot, keeps compact idle and expanded focused widths, and still uses the shared Home search binding for task, Timeline, Planner List, and Planner Calendar filtering. Pressing `Esc` or the toolbar `Esc` keycap dismisses focus without clearing the query; the in-field clear button clears the query and keeps focus in search.

## Consequences

- Search expansion has one visible animation source, avoiding `NSSearchField`'s delayed internal search-cell relayout.
- The search field remains AppKit-backed for keyboard focus and editor behavior, but no longer depends on native `NSSearchField` drawing.
- The query-clear affordance is Routina-owned rather than the native search-field `x`.
- Future toolbar-search visual changes should adjust the SwiftUI shell first and keep AppKit interop limited to text editing and responder behavior.
