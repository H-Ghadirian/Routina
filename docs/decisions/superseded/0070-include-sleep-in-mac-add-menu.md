# 0070: Include Sleep in the Mac Add Menu

## Status

Superseded

## Superseded By

- [0220: Nest Sleep and Gate Mac Event and Emotion Actions](../0220-nest-sleep-and-gate-mac-event-emotion-actions.md)

## Date

2026-05-26

## Supersedes

- [0066: Include Check In in the Mac Add Menu](superseded/0066-include-check-in-in-mac-add-menu.md)
- The sleep-button placement portion of [0039: Move Mac Check-In to the Home Toolbar](0039-move-mac-check-in-to-home-toolbar.md)

## Context

The Mac Home sidebar `+` menu has become the capture entry point for lightweight user actions: Note, Goal, Task, and Check In. Sleep is another quick app-level action, but it still had its own Home toolbar button, splitting capture actions across two nearby controls.

## Decision

The Mac Home sidebar `+` menu includes Note, Goal, Task, Check In, and Sleep. Sleep uses the existing shared Mac sleep starter, including the active-focus warning before sleep mode begins.

The standalone Home toolbar sleep button is removed. The Home toolbar keeps the compact place check-in menu for richer place status and map controls.

## Consequences

- The sidebar `+` menu is the primary Mac capture/action menu for quick note, goal, task, place, and sleep actions.
- Sleep behavior remains centralized in the existing sleep-mode support instead of adding a separate flow.
- The Mac Home toolbar has fewer standalone buttons while place check-in status remains available there.
