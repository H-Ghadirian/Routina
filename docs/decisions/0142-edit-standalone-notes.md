# 0142: Edit Standalone Notes

## Status

Accepted

## Date

2026-06-03

## Context

Standalone notes can be created from Home and reviewed from Timeline or Home detail surfaces. After capture, users need to correct or expand the same note without creating a replacement record, while still preserving when the note originally entered the timeline.

## Decision

Note detail surfaces expose an Edit action that reuses the standalone note editor with the existing title, body, tags, image, voice note, and file attachments prefilled.

Saving edits mutates the existing `RoutineNote`, keeps `createdAt` as the timeline/log date, refreshes `updatedAt`, and syncs linked `RoutineNoteAttachment` rows from the editor draft. Detail headers show the original note date and add an edited-date line, such as `Edited 28 May 2026`, when `updatedAt` is later than `createdAt`.

## Consequences

- Notes can be corrected without losing their original timeline position.
- The edited marker communicates that the note changed while keeping the note's primary date stable.
- Note editing continues to use the standalone note model and shared tag storage instead of task attachment flows.
