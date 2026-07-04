# 0330: Hoist Expanded Mac Toolbar Search Out of the Principal Item

## Status

Superseded

## Date

2026-07-04

## Refines

- [0317: Use Principal Search in Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)
- [0321: Use Focus-Expanded Mac Home Toolbar Search](0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](0323-draw-mac-toolbar-search-shell-in-swiftui.md)
- [0329: Hide Mac Toolbar Actions Only While Search Is Expanded](0329-hide-mac-toolbar-actions-during-search-focus.md)

## Superseded By

- [0334: Keep Expanded Mac Toolbar Search in the Principal Item](../0334-keep-expanded-mac-toolbar-search-in-principal-item.md)

## Refined By

- [0331: Stabilize Expanded Mac Toolbar Search in a Top Row](0331-stabilize-expanded-mac-toolbar-search-row.md)

## Context

At the 1200 x 720 minimum Mac Home window size, AppKit can drop the centered principal toolbar item entirely. That means a search command can hide other toolbar actions for focus but still leave no visible search field to type into.

Keeping the expanded search solely inside the principal toolbar item also makes the animation depend on AppKit relayout timing. During expansion, a full-width host can appear before the visible pill catches up, or the field can jump as the toolbar negotiates remaining space.

## Decision

Mac Home keeps the compact idle search in the centered principal toolbar slot when AppKit has enough room to show it.

When search becomes focused or expanded, Mac Home renders the same SwiftUI search pill and transparent AppKit text editor from the Home root as a top overlay aligned with the toolbar/titlebar band. The compact toolbar item is removed while this overlay is active, and non-search toolbar actions remain hidden until the overlay pill finishes collapsing.

The overlay mounts at the compact pill width before animating to the focused width. Menu and keyboard commands that focus search set the same expanded overlay state directly, so focused search remains visible and editable even when the compact principal toolbar item is absent at minimum width.

## Consequences

- Minimum-size Mac Home windows can focus and type into toolbar search even when the compact principal search item is not visible.
- The expanded search no longer relies on AppKit preserving the principal toolbar item during focused layout.
- Expansion starts from the visible compact pill width, avoiding the pre-animation wide oval behind the search field.
- Idle windows still use the normal compact toolbar search when AppKit can fit it, and normal toolbar actions return after collapse.
- Future search animation changes must keep the focused search available independently from AppKit toolbar item fitting.
