# 0339: Host Mac Home Search in the Window Titlebar

## Status

Superseded

## Date

2026-07-04

## Superseded By

- [0340: Use a SwiftUI Outlook-Style Mac Home Top Toolbar](../0340-use-swiftui-outlook-style-mac-home-top-toolbar.md)

## Supersedes

- [0338: Use Titlebar Principal Mac Home Search](0338-use-titlebar-principal-mac-home-search.md)

## Refines

- [0310: Show Mac Home Toolbar Search](../0310-show-mac-home-toolbar-search.md)
- [0315: Merge Mac Quick Add Into Toolbar Search](../0315-merge-mac-quick-add-into-toolbar-search.md)
- [0317: Use Principal Search in the Mac Home Toolbar](../0317-use-principal-search-in-mac-home-toolbar.md)
- [0321: Use Focus-Expanded Mac Home Toolbar Search](../0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](../0323-draw-mac-toolbar-search-shell-in-swiftui.md)
- [0329: Hide Mac Toolbar Actions During Search Focus](../0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

The principal-toolbar correction in [0338](0338-use-titlebar-principal-mac-home-search.md) still rendered the search field in the lower SwiftUI toolbar lane in the Routina Home window. In screenshots, the field remained visually below the titlebar instead of reading like Outlook for Mac's top-window search affordance.

The desired behavior was a true top/titlebar search strip: the search field should sit centered in the window's titlebar band while the Home command controls remain in the toolbar row beneath it. The control still needed to reuse the shared Home search binding, Quick Add shortcut focus, Return-to-create guard, AppKit first-responder behavior, and coordinated SwiftUI-drawn expand/collapse animation.

## Decision

Mac Home hosted the search-or-create field in the window frame/titlebar layer through a narrow AppKit bridge. The SwiftUI shell remained the source of truth for layout, text, focus, clear, `Esc`, create hints, and animations, while AppKit only mounted that SwiftUI view above the regular toolbar content.

The installer centered a fixed-width titlebar host in the standard window-button titlebar container, vertically aligned it with the standard macOS close/minimize/zoom button row, and added a small native titlebar accessory spacer below that row so the command toolbar sat underneath instead of being covered. Mouse events outside the visible pill passed through, so titlebar and toolbar interactions around the search field could keep working. The SwiftUI toolbar content owned only command controls such as Places, mode navigation, Add, Progress, and board inspector actions.

Quick-add parser previews remained owned by the Home shell and attached below the toolbar area as a centered dropdown surface. Task and Timeline sidebars still avoided a duplicate text field for the same shared Home search binding.

## Consequences

- Search visibly moved into the top window/titlebar band, aligned with the traffic-light buttons, with the command toolbar kept in its own row underneath.
- Home command toolbar controls stayed visible while search was focused or collapsing.
- Search placement no longer depended on AppKit's principal toolbar item fitting behavior.
- This approach was superseded because live builds clipped the host, covered command controls, and broke normal typing/focus and animation behavior.
