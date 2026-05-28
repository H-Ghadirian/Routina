# 0091: Use Native macOS Undo and Redo

- Status: Accepted
- Date: 2026-05-28

## Context

macOS users expect Undo and Redo to live in the standard Edit menu, use Command-Z and Shift-Command-Z, respect the focused window, and cooperate with text editing and other system controls. Routina also persists most user changes through SwiftData, so app-level undo needs to reverse saved model mutations rather than only local view state.

Building a custom history stack would duplicate behavior AppKit and SwiftUI already provide, risk fighting focused text fields, and make Routina less consistent with current macOS conventions.

## Decision

Routina for macOS uses the active window's native `UndoManager` as the undo/redo authority. SwiftData model contexts used by user-driven mutations should attach to that undo manager so saved app edits participate in the standard Edit > Undo and Edit > Redo commands and their system keyboard shortcuts.

When a mutation path previously used a short-lived SwiftData context for a user action, macOS may route that action through the shared main context while an undo manager is active so the native undo stack can persist and refresh the app after undo or redo.

Programmatic maintenance, launch bookkeeping, sync repair, migrations, widget refreshes, and other non-user mutations should avoid registering undo actions. They can run before the undo bridge is installed, use non-undo contexts, or temporarily disable undo registration.

## Consequences

- The app keeps the platform-owned Edit menu and shortcuts instead of replacing them with Routina-specific command handling.
- Text field undo/redo remains native because the app participates in the window undo manager rather than intercepting Command-Z globally.
- User-facing SwiftData mutations should use the shared undo-aware context helper when they need a detached mutation context.
- Undo/redo saves the SwiftData context and posts Routina's normal data-refresh notification so Home, Goals, Timeline, Stats, widgets, and toolbar badges can update after the reversal.
