# 0065: Open Timeline Notes and Places From Rows

## Status

Accepted

## Date

2026-05-26

## Context

Timeline rows mix task outcomes, standalone notes, sleep, and place check-ins. Tasks already open their detail screen from timeline rows, and notes can be deep-linked, but note and place rows need the same direct review behavior when selected from the timeline.

## Decision

Timeline note rows open `RoutineNoteDetailView`, and place check-in rows open a dedicated `PlaceCheckInSessionDetailView`. This applies to standalone Timeline screens and the macOS Home embedded Timeline detail column.

The place detail screen is read-oriented and shows the check-in place, time range, duration, activity, note, image, and saved location metadata. Editing still belongs to the existing Places/check-in history correction surfaces unless a later decision supersedes that.

## Consequences

- Timeline rows behave consistently: selecting an entry opens the most specific available detail.
- Place check-ins can be reviewed without first opening the map/check-in workspace.
- Future timeline entry types should provide a detail surface before falling back to an informational empty state.
