# 0329: Hide Mac Toolbar Actions Only While Search Is Expanded

## Status

Accepted

## Date

2026-07-03

## Refines

- [0321: Use Focus-Expanded Mac Home Toolbar Search](0321-use-focus-expanded-mac-home-toolbar-search.md)
- [0323: Draw Mac Toolbar Search Shell in SwiftUI](0323-draw-mac-toolbar-search-shell-in-swiftui.md)

## Supersedes

- [0327: Animate Mac Toolbar Search as One Visible Pill](superseded/0327-animate-mac-toolbar-search-as-one-visible-pill.md)

## Context

Mac Home search expansion repeatedly exposed a toolbar-layout race: AppKit could briefly keep the old compact principal item while SwiftUI introduced a wider focused search item. This made the icon, placeholder, and focused shell appear as separate moving pieces.

Keeping task-detail toolbar actions visible while search expands also creates a layout conflict when the right task-detail pane is open. The right-side action buttons need their toolbar space while search is idle, but focused search needs room for the wider visible search pill.

An earlier attempt reserved a wide search host before and after focus to stabilize the transition. That avoided some overlap, but it left a long empty oval visible in the default toolbar and hid toolbar controls when search was not visibly expanded.

## Decision

Mac Home hides non-search toolbar content while the toolbar search field is expanded/focused or visibly collapsing. Hidden items include navigation controls, Done badges, board inspector toolbar buttons, and Task Details toolbar actions.

The default toolbar remains normal: the search field is compact and other toolbar actions stay visible. The search field must not show a wide idle host, and the wide oval should not become a permanent container for unrelated toolbar actions. The search pill should size from the same width it visibly draws; it must not use a separate expanded toolbar layout width that can appear before the pill catches up or cause AppKit to drop the item in regular windows. On dismissal, actions return after the visible pill finishes collapsing so they do not reappear underneath the wide pill.

The visible SwiftUI search pill, icon, placeholder, clear affordance, and Esc affordance continue to animate together around a transparent AppKit text editor. That editor remains responsible for first responder behavior, Return, Esc, and focus restoration.

## Consequences

- Idle Home keeps the compact centered search field and leaves task-detail toolbar actions visible.
- Expanded and collapsing search hide other toolbar items, avoiding overlap with right-side task-detail controls.
- Focused search uses one visible pill width for sizing and drawing, avoiding a second oval behind the animated search pill.
- Focused search width stays within regular macOS window toolbar capacity so the principal search item remains available outside fullscreen.
- Idle collapsed search returns to the compact search field plus normal toolbar actions; no extra wide host remains in the idle toolbar.
- Future Mac Home toolbar additions should participate by hiding their toolbar items while search is expanded or collapsing, not while search is merely present.
