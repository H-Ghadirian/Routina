# 0620: Remember the Last Mac Focus Picker Duration

## Status

Accepted

## Date

2026-08-20

## Refines

- [0603: Start Mac Focus From One Recalling Sheet](0603-start-mac-focus-from-one-recalling-sheet.md)

## Context

The Mac Focus sheet derived its initial duration from the most recent
attributed Focus session. That covered a successfully started session, but it
did not preserve a duration the person selected and then canceled, and the
sheet did not identify the restored value as the last choice.

## Decision

The Mac Focus sheet stores the selected duration in device-local app
preferences whenever a duration choice is made and again after a successful
start. The remembered duration is shown as Last choice and is selected when
the sheet opens. It takes precedence over synchronized Focus-session history;
session history remains the fallback for existing installations that have no
remembered picker choice, and the default remains 25 minutes when neither
source has a value.

This preference applies only to the duration. Task rows remain explicit start
actions, and tag preselection continues to follow the available latest
attributed tag behavior from Decision 0603.

## Consequences

- A canceled or completed duration choice is ready the next time Focus opens.
- The sheet makes the remembered value visible instead of requiring the person
  to infer it from the selected pill.
- The preference is device-local and does not change Focus-session history or
  synchronization.
