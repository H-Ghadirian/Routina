# 0226: Hide Mac Status Note Section Behind Beta Toggle

## Status

Accepted

## Date

2026-06-13

## Refines

- [0206](0206-capture-status-from-mac-sidebar.md)

## Context

The Mac Home sidebar status composer makes capture very fast, but it also occupies persistent sidebar space and asks for a status note on every Home surface. Routina already uses Settings -> General -> Beta Experiments to keep optional or still-stabilizing Mac surfaces available without making the default Home UI dense.

## Decision

Mac Home hides the bottom Status note sidebar composer by default. Users can enable it from Settings -> General -> Beta Experiments with the `appSettingMacStatusComposerEnabled` flag.

When enabled, the composer keeps the behavior from [0206](0206-capture-status-from-mac-sidebar.md): submitted text is saved as a standalone note tagged `Status` and appears in Timeline.

## Consequences

- Default Mac Home sidebar navigation is quieter and has more vertical room.
- Status note capture remains available as an explicit beta experiment.
- No SwiftData migration is needed because the change only gates the existing composer surface.
