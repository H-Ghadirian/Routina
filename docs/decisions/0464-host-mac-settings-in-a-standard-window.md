# 0464: Host Mac Settings in a Standard Window

## Status

Accepted

## Date

2026-07-29

## Supersedes

[0461: Use Standard Window Controls for Mac Settings](superseded/0461-use-standard-window-controls-for-mac-settings.md)

## Context

Decision 0461 kept SwiftUI's special `Settings` scene and attempted to restore
desktop window behavior by changing the attached `NSWindow` style mask,
maximum size, collection behavior, and traffic-light button state.

Those changes made minimize and resize available, but the underlying scene
remained a preference-panel host and still refused native full screen. Window
capabilities imposed by the scene host cannot be reliably widened by mutating
the resulting window after attachment.

## Decision

Routina hosts its standalone Mac Settings surface in a standard,
single-instance SwiftUI `Window` scene. The window:

- is suppressed at app launch;
- keeps the existing 640 by 560 minimum content size;
- supports native minimize, resize, zoom, and full screen; and
- reuses the existing Settings content, persistence, app-lock, and undo
  environment.

Because an ordinary `Window` does not create the system Settings command,
Routina replaces the app-settings command group with a `Settings…` command
that opens the single settings window and retains the Command-comma shortcut.

The special SwiftUI `Settings` scene and its post-attachment AppKit window
configurator are removed.

## Consequences

- The Settings window can enter and leave a dedicated full-screen Space.
- Settings remains single-instance and opens through the expected app menu and
  Command-comma shortcut.
- Settings does not appear automatically when the app launches.
- Window capability requirements must be satisfied by the chosen scene host,
  not by assuming that later `NSWindow` mutation can override host policy.
