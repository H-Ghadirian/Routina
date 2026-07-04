# 0337: Use Separate Mac Home Top Search Toolbar

## Status

Superseded

## Date

2026-07-04

## Supersedes

- [0334: Keep Expanded Mac Toolbar Search in the Principal Item](0334-keep-expanded-mac-toolbar-search-in-principal-item.md)

## Superseded By

- [0338: Use Titlebar Principal Mac Home Search](0338-use-titlebar-principal-mac-home-search.md)

## Refines

- [0310: Show Mac Home Toolbar Search](../0310-show-mac-home-toolbar-search.md)
- [0315: Merge Mac Quick Add Into Toolbar Search](../0315-merge-mac-quick-add-into-toolbar-search.md)
- [0317: Use Principal Search in the Mac Home Toolbar](../0317-use-principal-search-in-mac-home-toolbar.md)
- [0321: Use Focus-Expanded Mac Home Toolbar Search](../0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](../0323-draw-mac-toolbar-search-shell-in-swiftui.md)
- [0329: Hide Mac Toolbar Actions During Search Focus](../0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

The principal-toolbar search kept the global search affordance compact and stable, but it still made search feel tied to AppKit toolbar fitting behavior. It also required main Home toolbar commands to hide while search expanded, even though the desired Outlook-style layout gives search its own top lane and leaves command controls in their row.

The search field still needs the existing shared Home search binding, Quick Add shortcut focus, Return-to-create guard, AppKit first-responder behavior, and coordinated SwiftUI-drawn expand/collapse animation.

## Decision

Mac Home renders the search-or-create field in a root-owned top search toolbar band above the split content instead of in the centered principal toolbar item. The native toolbar keeps compact Home command controls such as Places, mode navigation, Add, Progress, and board inspector actions visible while search is focused or collapsing.

The top search toolbar reuses the SwiftUI-drawn search shell around the transparent AppKit text editor. It stays compact while idle, expands while focused, supports `Esc` dismissal without clearing the query, keeps the in-field clear affordance, and continues to focus from the configurable Search or Create shortcut. Quick-add parser previews attach below the top search band as a dropdown-style surface rather than being owned by the main content overlay.

Task and Timeline sidebars still avoid a duplicate text field for the same shared Home search binding.

## Consequences

- Search no longer depends on AppKit keeping the principal toolbar item visible at tight sizes.
- Home command toolbar controls do not disappear just because search is focused.
- The search band pushes the split content down by a stable toolbar height while parser previews float below it.
- Future Home toolbar changes should treat the top search band as the global search surface and keep command controls in the native toolbar row unless a later decision revises this layout again.
