# 0326: Stabilize Mac Toolbar Search Animation Stage

## Status

Superseded

## Date

2026-07-01

## Refines

- [0321: Use Focus-Expanded Mac Home Toolbar Search](../0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](../0323-draw-mac-toolbar-search-shell-in-swiftui.md)

## Superseded By

- [0327: Animate Mac Toolbar Search as One Visible Pill](0327-animate-mac-toolbar-search-as-one-visible-pill.md)

## Context

The Mac Home toolbar search should expand and collapse like one object. Drawing the visible search shell in SwiftUI removed the native `NSSearchField` content delay, but the principal toolbar item still changed its reported width when focus changed. AppKit immediately re-laid out the toolbar item before SwiftUI finished animating, which made the search jump horizontally, briefly show an oversized shell, or collapse under the Home mode strip.

## Decision

Mac Home gives the principal toolbar search a stable focused-width animation stage. That stage is layout-only and must not draw a background, stroke, or hover surface. The visible SwiftUI search shell remains compact while idle and expands while focused, but that visible width animation happens inside the fixed stage instead of changing the toolbar item's layout footprint.

The clear affordance, create hint, and `Esc` focus-dismiss keycap live inside the SwiftUI shell so they do not add or remove width beside the shell during the toolbar animation.

## Consequences

- Expansion and collapse are local SwiftUI animations instead of AppKit toolbar relayouts.
- The search shell, icon, placeholder, text editor, clear button, create hint, and `Esc` keycap move together.
- Idle search shows only the compact visible pill, not the full focused-width stage.
- The principal toolbar slot reserves the focused animation stage even while the visible shell is compact. If future toolbar action crowding returns, adjust the stage width or make the focused stage adaptive rather than changing the toolbar item's reported width during focus transitions.

## Supersession Note

This approach still exposed a giant toolbar oval in practice because the principal toolbar hosting view could receive a visible treatment across the focused-width stage. [0327](0327-animate-mac-toolbar-search-as-one-visible-pill.md) replaced it by removing the separate stage and keeping only one visible search pill.
