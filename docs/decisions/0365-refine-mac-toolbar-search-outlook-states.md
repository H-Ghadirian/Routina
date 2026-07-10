# 0365: Refine Mac Toolbar Search Outlook States

Date: 2026-07-10

Status: Accepted

Refines: [0321 Use Focus-Expanded Mac Home Toolbar Search](0321-use-focus-expanded-mac-home-toolbar-search.md), [0323 Draw Mac Toolbar Search Shell in SwiftUI](0323-draw-mac-toolbar-search-shell-in-swiftui.md), [0341 Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

The Mac Home toolbar search already used a SwiftUI-drawn Outlook-style pill around an AppKit text editor, but its idle and focused states were still too visually similar. The idle placeholder also sat at the leading text position instead of reading as a centered closed search affordance. The focused width did not give the active editor enough room, and clicks in some visible empty parts of the pill could be noticed by the outside-click monitor without actually focusing the AppKit editor.

## Decision

Mac Home keeps the existing SwiftUI shell and transparent AppKit editor, but makes the closed and focused states visually distinct. The idle empty search pill centers the magnifying-glass icon and placeholder as one group. The focused pill uses a different background/stroke treatment, expands wider than before, and keeps the editor left-aligned with the leading icon, clear button, create hint, and `Esc` keycap inside the same animated surface.

Every click inside the visible search pill requests focused editing, including clicks on empty shell areas that are not directly over the AppKit text editor. While focused, the visible search pill advertises an I-beam cursor across its full surface.

## Consequences

- The closed search affordance reads more like Outlook's centered idle search bar.
- Focused search has more typing and quick-add space without introducing a second idle host.
- Empty visible areas inside the pill focus the editor instead of becoming dead click zones.
- Cursor feedback stays consistent with text editing while the search field is focused.
