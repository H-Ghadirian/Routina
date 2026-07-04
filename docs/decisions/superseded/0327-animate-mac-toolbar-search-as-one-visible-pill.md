# 0327: Animate Mac Toolbar Search as One Visible Pill

## Status

Superseded

## Date

2026-07-01

## Refines

- [0321: Use Focus-Expanded Mac Home Toolbar Search](../0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](../0323-draw-mac-toolbar-search-shell-in-swiftui.md)

## Supersedes

- [0326: Stabilize Mac Toolbar Search Animation Stage](0326-stabilize-mac-toolbar-search-animation-stage.md)

## Superseded By

- [0329: Hide Mac Toolbar Actions During Search Focus](../0329-hide-mac-toolbar-actions-during-search-focus.md)

## Context

Mac Home search expansion should feel like Outlook: one search surface grows while its icon, placeholder, typed text, clear affordance, create hint, and `Esc` keycap move with it. Changing the toolbar item's reported width during focus transitions lets AppKit briefly keep the old compact placement while SwiftUI lays out the expanded placement, making the icon and text appear to lag behind the shell.

The separate focused-width animation stage from 0326 was directionally useful for preventing toolbar relayout, but the stage must be inert. If the host carries background, stroke, help, accessibility, or hit semantics, it can appear as a giant oval behind the compact idle search bar.

## Decision

Mac Home keeps the toolbar search host compact while idle so task-detail toolbar actions have room. While search is focused, and briefly while the collapse animation finishes, the host uses the focused width so AppKit does not reposition the principal item during the visible transition. That active host is invisible and inert: it draws no background or stroke and owns no hit, help, or accessibility surface.

The SwiftUI search shell is the only visible pill: compact while idle and focused-width while active. Its rounded background and stroke are applied only after the shell is framed to the current visible width.

The transparent AppKit text editor remains inside the SwiftUI shell for first responder, Return, Esc, and focus-restoration behavior. Search adornments remain inside the same shell so there is only one rounded search surface at every animation frame.

Click dismissal is also tied to that visible shell, not the wider invisible host. While search is focused, pointer clicks outside the visible pill dismiss the text editor and let search collapse; clicks inside the pill keep the search active so the text field, clear button, and `Esc` keycap remain usable.

## Consequences

- Idle search shows exactly one compact oval.
- Focused search still expands with its icon, text, placeholder, clear button, create hint, and `Esc` keycap in the same surface.
- Clicking outside the visible search pill collapses focused search without letting the invisible focused-width host consume nearby toolbar or task-detail actions.
- The toolbar item reserves focused width only during active search and collapse, then releases back to compact idle width so task-detail toolbar buttons remain visible.
- Future animation fixes should preserve the one-visible-pill invariant: any active layout host must stay invisible, and all search chrome must live on the inner shell.
