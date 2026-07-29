# 0461: Use Standard Window Controls for Mac Settings

## Status

Superseded

## Superseded By

[0464: Host Mac Settings in a Standard Window](../0464-host-mac-settings-in-a-standard-window.md)

## Date

2026-07-29

## Context

Routina presents its Mac settings through SwiftUI's dedicated `Settings`
scene. That scene preserves the standard Settings menu and Command-comma
routing, but its preference-panel window policy disabled minimize, resize,
zoom, and native full-screen behavior even though Routina's settings use a
multi-column layout that benefits from more space.

Replacing the scene with an ordinary window would require Routina to recreate
system Settings routing and window ownership.

## Decision

Routina keeps the SwiftUI `Settings` scene and its system Settings command, but
uses content-minimum window resizability and configures the attached native
window to support the standard macOS capabilities:

- minimize;
- free resizing above Routina's existing settings minimum size;
- zoom/maximize; and
- native full screen.

The configuration removes the preference scene's fixed maximum size, restores
the miniaturize and zoom buttons, and marks the window as a primary full-screen
window. No Settings navigation, persistence, or content layout behavior
changes.

## Consequences

- Settings continues opening through the normal app Settings command.
- Users can minimize Settings or expand it to the available desktop or a
  dedicated full-screen Space.
- The existing 640 by 560 content minimum remains the lower size bound.
- Future Settings scene changes must preserve standard window capabilities
  unless a new product decision deliberately narrows them.
