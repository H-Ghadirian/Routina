# 0331: Stabilize Expanded Mac Toolbar Search in a Top Row

## Status

Superseded

## Date

2026-07-04

## Refines

- [0330: Hoist Expanded Mac Toolbar Search Out of the Principal Item](0330-hoist-expanded-mac-toolbar-search.md)

## Superseded By

- [0334: Keep Expanded Mac Toolbar Search in the Principal Item](../0334-keep-expanded-mac-toolbar-search-in-principal-item.md)

## Context

The focused Mac Home search field must remain visible when AppKit drops the compact principal toolbar item at minimum window width. The first hoisted implementation used a root overlay with a negative top offset so the expanded pill appeared near the toolbar band.

That overlay was still too sensitive to window chrome, fullscreen layout, right-side companion panes, and non-Planner workspaces. It could appear in the wrong vertical position, disappear behind the fullscreen toolbar area, or obscure unrelated toolbar state.

## Decision

Mac Home keeps compact idle search in the centered principal toolbar slot when AppKit can fit it.

When search is expanded, Mac Home removes the compact principal item and renders the expanded SwiftUI search pill in a root-owned top safe-area row. The row is layout-owned instead of positioned with a titlebar offset, clamps the pill to available width, and keeps the visible pill, text editor, clear affordance, create hint, and `Esc` keycap inside the same bounded surface.

The expanded search row hides main Home toolbar command actions while active, but sidebar status toolbar badges such as development-version and done-count badges remain visible because they are not part of the main Home command row.

## Consequences

- Focused search remains visible in fullscreen, at the minimum Mac Home size, and while right-side companion panes are open.
- The expanded search no longer depends on AppKit titlebar measurements or negative overlay padding.
- Main toolbar command actions can still hide while search is expanded, but sidebar toolbar status remains stable.
- Search internals must compress or truncate inside the pill rather than overflow beyond the rounded surface.
