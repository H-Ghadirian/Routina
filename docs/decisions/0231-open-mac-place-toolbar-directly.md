# 0231: Open Mac Place Toolbar Directly

## Status

Accepted

## Date

2026-06-13

## Supersedes

- Part of [0039: Move Mac Check-In to the Home Toolbar](0039-move-mac-check-in-to-home-toolbar.md)

## Context

The Mac Home toolbar place control originally opened a compact menu for place status, saved-place check-in suggestions, opening Places, and ending the active check-in. Once Places became the map-first correction and capture surface, those menu actions made the toolbar control feel heavier than its job: showing current place context and getting the user to Places.

## Decision

The Mac Home toolbar place control is a direct button. It keeps the compact current check-in label when a place session is active, but clicking it opens the Places screen immediately. It does not expose a dropdown menu, saved-place suggestions, or an end-check-in action.

Check-in creation, correction, ending, and history review should happen in the Places surface instead of the top toolbar control.

## Consequences

- The top toolbar stays compact and predictable.
- Users can reach Places with one click from the current-place label.
- Place management actions remain centralized in Places rather than split between toolbar and map/sidebar surfaces.
