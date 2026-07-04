# 0338: Use Titlebar Principal Mac Home Search

## Status

Superseded

## Date

2026-07-04

## Superseded By

- [0339: Host Mac Home Search in the Window Titlebar](0339-host-mac-home-search-in-window-titlebar.md)

## Supersedes

- [0337: Use Separate Mac Home Top Search Toolbar](0337-use-separate-mac-home-top-search-toolbar.md)

## Refines

- [0310: Show Mac Home Toolbar Search](../0310-show-mac-home-toolbar-search.md)
- [0315: Merge Mac Quick Add Into Toolbar Search](../0315-merge-mac-quick-add-into-toolbar-search.md)
- [0317: Use Principal Search in the Mac Home Toolbar](../0317-use-principal-search-in-mac-home-toolbar.md)
- [0321: Use Focus-Expanded Mac Home Toolbar Search](../0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](../0323-draw-mac-toolbar-search-shell-in-swiftui.md)
- [0329: Hide Mac Toolbar Actions During Search Focus](../0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

The first separate-top-toolbar implementation in [0337](0337-use-separate-mac-home-top-search-toolbar.md) gave search its own visual lane, but it mounted that lane as a content safe-area inset below the native toolbar. That pushed the Planner and sidebar down and made search read as part of the content, not as the Outlook-style top toolbar/titlebar search affordance.

The desired layout was closer to Outlook for Mac: search belonged in the top titlebar/principal toolbar area, while compact command controls stayed in the toolbar command row below it.

## Decision

Mac Home rendered the search-or-create field as the native toolbar principal item so it would appear in the top titlebar/toolbar area. The native command row kept compact Home command controls such as Places, mode navigation, Add, Progress, and board inspector actions visible while search was focused or collapsing.

The search item reused the SwiftUI-drawn search shell around the transparent AppKit text editor.

## Consequences

- This approach still landed in the lower SwiftUI toolbar lane for the Routina Home window.
- [0339](0339-host-mac-home-search-in-window-titlebar.md) replaced the principal-item assumption with a window-frame titlebar host.
