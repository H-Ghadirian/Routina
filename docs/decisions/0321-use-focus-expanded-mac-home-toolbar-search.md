# 0321: Use Focus-Expanded Mac Home Toolbar Search

## Status

Accepted

## Date

2026-07-01

## Refines

- [0022: Own Mac Home Toolbar at the Split Shell](0022-own-mac-home-toolbar-at-split-shell.md)
- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)

## Context

The centered Mac Home search field gives search a stable global place, but its wide default size can crowd trailing task-detail toolbar actions when the left sidebar is open. Full task details still need Pause, Done, link, edit, minimize, and close controls to remain visible during ordinary review.

The search field should feel prominent when the user is actively searching or creating, while leaving room for task-detail controls when it is idle.

## Decision

Mac Home keeps the AppKit-backed search-or-create field as the centered principal toolbar item, but renders it at a compact width by default. When the search field becomes first responder, it smoothly expands to a larger focused width so search and quick-add creation can temporarily take priority in the toolbar.

The focused state is owned by the AppKit `NSSearchField` bridge so keyboard shortcut focusing, typing focus restoration, and intentional focus moves into other text editors keep their existing semantics. The inline `Return` / `Create task` hint and parser preview are shown only while the search field is focused, and the parser preview uses the focused search width.

Focused search can be dismissed without clearing the current query by pressing `Esc` or using the toolbar search `Esc` keycap button. The native search-field `x` remains the affordance for clearing the current query.

## Consequences

- Full task-detail toolbar actions have room to stay visible when the sidebar is open and search is idle.
- Search remains the principal toolbar affordance and can expand when the user actively works in it.
- Users have explicit pointer and keyboard exits from focused search before returning to toolbar actions.
- Quick Add shortcut behavior, result filtering, and no-result Return-to-create semantics remain unchanged.
