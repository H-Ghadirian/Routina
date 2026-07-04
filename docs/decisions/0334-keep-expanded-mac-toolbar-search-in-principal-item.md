# 0334: Keep Expanded Mac Toolbar Search in the Principal Item

## Status

Accepted

## Date

2026-07-04

## Supersedes

- [0330: Hoist Expanded Mac Toolbar Search Out of the Principal Item](superseded/0330-hoist-expanded-mac-toolbar-search.md)
- [0331: Stabilize Expanded Mac Toolbar Search in a Top Row](superseded/0331-stabilize-expanded-mac-toolbar-search-row.md)

## Refines

- [0321: Use Focus-Expanded Mac Home Toolbar Search](0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](0323-draw-mac-toolbar-search-shell-in-swiftui.md)
- [0329: Hide Mac Toolbar Actions During Search Focus](0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

The hoisted expanded-search implementations tried to keep focused search visible when AppKit dropped the principal toolbar item at tight sizes. In practice, rendering search as a separate root overlay or top safe-area row made placement unstable across fullscreen, minimum-size windows, companion panes, and non-Planner surfaces.

That separate surface also made the animation harder to reason about because focus, toolbar item mounting, parser preview placement, and sidebar toolbar state all had to coordinate across two different search hosts.

## Decision

Mac Home keeps the search-or-create field mounted in the centered principal toolbar item while it expands and collapses. Main Home toolbar command actions still hide while search is expanded, focused, or visibly collapsing, but the app no longer renders a second expanded search surface from the Home root.

The SwiftUI search pill remains compact while idle and animates its visible width while focused. Its magnifying-glass icon, text editor, clear affordance, create hint, and `Esc` keycap stay inside the same bounded pill. Sidebar status toolbar badges remain visible during search focus because they are outside the main Home command row.

## Consequences

- Search expansion no longer depends on a separately positioned overlay or top safe-area row.
- The principal toolbar item is the only search surface, reducing duplicate focus and placement paths.
- Main toolbar action hiding remains available to create room for focused search.
- At window sizes where AppKit cannot fit the principal toolbar item, Routina accepts the native toolbar fitting behavior instead of adding a second search host.
