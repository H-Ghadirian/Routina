# 0340: Use a SwiftUI Outlook-Style Mac Home Top Toolbar

## Status

Accepted

## Date

2026-07-04

## Supersedes

- [0339: Host Mac Home Search in the Window Titlebar](superseded/0339-host-mac-home-search-in-window-titlebar.md)

## Refines

- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0315: Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)
- [0321: Use Focus-Expanded Mac Home Toolbar Search](0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](0323-draw-mac-toolbar-search-shell-in-swiftui.md)
- [0329: Hide Mac Toolbar Actions During Search Focus](0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

The titlebar-host approach in [0339](superseded/0339-host-mac-home-search-in-window-titlebar.md) visually targeted the Outlook-style search placement, but in live builds the detached AppKit host clipped at the top of the window, covered command controls, and broke normal typing/focus and animation behavior.

The desired product behavior remains Outlook-like: global search sits centered in the same top visual band as the macOS traffic-light buttons, while Home command controls live in a separate row below it. The implementation should not detach search from the main SwiftUI hierarchy.

## Decision

Mac Home renders a root-owned SwiftUI top toolbar chrome above the Home split content. The chrome has a titlebar-height search row and a separate command row underneath it. The search row centers the shared search-or-create field, keeps the SwiftUI-drawn pill around the transparent AppKit text editor, and preserves compact idle and focused widths. The command row keeps Home controls such as Places, mode navigation, Add, optional Progress, Done status, and board inspector controls visible without sharing the search row.

The Home split view is laid out below this chrome instead of being covered by an overlay. Quick-add parser previews and created-task toasts attach below the top toolbar chrome. The implementation must not use a detached titlebar hosting view, titlebar accessory spacer, or native principal toolbar item for the Home search field.

## Consequences

- Search keeps the Outlook-like top placement while remaining editable and animated inside the main SwiftUI view tree.
- Home content is pushed below the top toolbar, so search no longer covers the Planner header or sidebar.
- Command controls remain visible in their own row while search is focused or collapsing.
- Future Home toolbar changes should preserve the two-row SwiftUI chrome unless a later decision explicitly revises the Mac Home search model.
