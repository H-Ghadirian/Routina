# 0154: Present Mac Away Start Inline

## Status

Accepted

## Date

2026-06-04

## Refines

- [0125: Support Away Sessions](0125-support-away-sessions.md)
- [0070: Include Sleep in Mac Add Menu](0070-include-sleep-in-mac-add-menu.md)

## Context

Away sessions are first-class protected time, but the Mac Add menu presented the Away starter as a sheet. That made Away feel detached from the main Home workspace and could cover the current context.

Mac Home already prefers inline creation and editing for several primary capture flows so the detail area remains the place where work happens.

## Decision

On macOS, choosing Away from the Home Add menu opens the Away starter in the main Home detail area instead of presenting it as a sheet. The form keeps explicit Cancel and Start actions, and starting Away still creates the same active `AwaySession` and full-screen Away mode.

The reusable Away starter keeps sheet dismissal behavior for hosts that still present it modally, but Mac Home passes callbacks so Cancel or Start closes the inline detail state without relying on modal dismissal.

## Consequences

- Away setup feels like part of the Home workspace rather than a transient pop-up.
- Mac navigation and toolbar state should treat the inline Away starter like other temporary creation surfaces.
- Existing session storage, timers, blockers, planner blocks, stats, backup/import, and count-up behavior are unchanged.
